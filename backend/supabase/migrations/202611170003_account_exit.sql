alter table app_private.pairs add column ended_at timestamptz;

create table app_private.account_deletions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique,
  stage text not null default 'pending' check (stage in ('pending', 'auth_pending', 'complete')),
  requested_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  lease_token uuid,
  lease_until timestamptz,
  attempts integer not null default 0,
  retry_at timestamptz not null default clock_timestamp(),
  last_error text
);
alter table app_private.account_deletions enable row level security;
revoke all on app_private.account_deletions from public, anon, authenticated, service_role;

create function app_private.end_pair(target uuid) returns void
language plpgsql set search_path = '' as $$
begin
  update app_private.pairs set status = 'ended', ended_at = clock_timestamp(), revision = revision + 1
    where id = target and status = 'active';
  update app_private.pair_members set active = false where pair_id = target;
  update app_private.invitations set status = 'cancelled'
    where status = 'active' and inviter_id in
      (select user_id from app_private.pair_members where pair_id = target);
  update app_private.approvals set plant_confirmed_at = null where pair_id = target;
  update app_private.cultivations set archived_at = coalesce(archived_at, clock_timestamp()) where pair_id = target;
end;
$$;

create function public.end_pair(pair_id uuid, expected_pair_revision integer, operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  pair app_private.pairs;
  receipt app_private.receipts;
  fingerprint text;
begin
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  select * into pair from app_private.pairs p where p.id = $1
    and exists (select 1 from app_private.pair_members m where m.pair_id = p.id and m.user_id = actor)
    for update;
  if not found then return app_private.error('pair_unavailable'); end if;
  if operation_id is null or expected_pair_revision is null then return app_private.error('validation_failed'); end if;
  fingerprint := encode(extensions.digest(jsonb_build_array($1, $2)::text, 'sha256'), 'hex');
  select * into receipt from app_private.receipts r where r.user_id = actor and r.operation_id = $3;
  if found then
    if receipt.operation <> 'end_pair' or receipt.payload_hash <> fingerprint then
      return app_private.error('operation_conflict');
    end if;
    return '{"ok":true}'::jsonb;
  end if;
  if pair.status <> 'active' then return app_private.error('pair_unavailable'); end if;
  if pair.revision <> expected_pair_revision then return app_private.error('version_conflict'); end if;
  perform app_private.end_pair(pair.id);
  insert into app_private.receipts(user_id,operation_id,operation,payload_hash,result_id)
    values(actor,$3,'end_pair',fingerprint,pair.id);
  return '{"ok":true}'::jsonb;
end;
$$;

-- Todas las RPC anteriores verifican también la existencia de la cuenta y su baja.
-- El bloqueo compartido serializa esta comprobación con la solicitud de eliminación.
do $wrappers$
declare
  fn record;
  arguments text;
begin
  for fn in
    select p.oid, p.proname, p.pronargs, pg_get_function_arguments(p.oid) as args,
      pg_get_function_identity_arguments(p.oid) as signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'register_profile','get_connection_state','create_invitation','resolve_invitation',
      'accept_invitation','cancel_invitation','get_pair_state','submit_selection',
      'reopen_selection','update_agreement','approve_agreement','confirm_planting',
      'withdraw_planting','mark_milestone_seen','end_pair'
    )
  loop
    select string_agg('$' || i, ', ' order by i) into arguments from generate_series(1,fn.pronargs) i;
    execute format('alter function public.%I(%s) set schema app_private', fn.proname, fn.signature);
    execute format('alter function app_private.%I(%s) rename to %I', fn.proname, fn.signature, 'active_' || fn.proname);
    execute format('revoke all on function app_private.%I(%s) from public, anon, authenticated, service_role',
                   'active_' || fn.proname, fn.signature);
    execute format($body$
      create function public.%I(%s) returns jsonb
      language plpgsql volatile security definer set search_path = '' as $wrapped$
      begin
        perform pg_advisory_xact_lock_shared(hashtextextended(auth.uid()::text || ':lifecycle', 0));
        if auth.uid() is null or not exists (select 1 from auth.users where id = auth.uid()) then
          return app_private.error('auth');
        end if;
        if exists (select 1 from app_private.account_deletions where user_id = auth.uid()) then
          return app_private.error('account_deleting');
        end if;
        return app_private.%I(%s);
      end;
      $wrapped$;
    $body$, fn.proname, fn.args, 'active_' || fn.proname, coalesce(arguments,''));
    execute format('revoke all on function public.%I(%s) from public, anon, service_role', fn.proname, fn.signature);
    execute format('grant execute on function public.%I(%s) to authenticated', fn.proname, fn.signature);
  end loop;
end;
$wrappers$;

-- Una aceptación que estaba en curso tampoco puede vincular una cuenta en baja.
create function app_private.reject_deleted_member() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.active and exists (select 1 from app_private.account_deletions d where d.user_id = new.user_id) then
    raise exception 'account_deleting' using errcode = '42501';
  end if;
  return new;
end;
$$;
create trigger reject_deleted_member before insert or update of active on app_private.pair_members
for each row execute function app_private.reject_deleted_member();

create function public.request_account_deletion() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  job uuid;
  linked record;
begin
  if actor is null then return app_private.error('auth'); end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text || ':lifecycle', 0));
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  if not exists (select 1 from auth.users where id = actor) then return app_private.error('auth'); end if;
  insert into app_private.account_deletions(user_id) values(actor)
    on conflict(user_id) do nothing;
  select id into job from app_private.account_deletions where user_id = actor;
  for linked in
    select p.id from app_private.pairs p
    join app_private.pair_members m on m.pair_id = p.id
    where m.user_id = actor and p.status = 'active' order by p.id for update of p
  loop
    perform app_private.end_pair(linked.id);
  end loop;
  update app_private.invitations set status = 'cancelled' where inviter_id = actor and status = 'active';
  return jsonb_build_object('ok',true,'deletion_requested',true);
end;
$$;

-- Sólo un proceso administrativo puede reclamar, purgar y finalizar una tarea.
create function public.claim_account_deletion() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  job app_private.account_deletions;
begin
  select * into job from app_private.account_deletions
    where stage <> 'complete' and retry_at <= clock_timestamp()
      and (lease_until is null or lease_until < clock_timestamp())
    order by requested_at for update skip locked limit 1;
  if not found then return '{"ok":true,"job":null}'::jsonb; end if;
  update app_private.account_deletions set lease_token = gen_random_uuid(),
    lease_until = clock_timestamp() + interval '5 minutes', attempts = attempts + 1
    where id = job.id returning * into job;
  return jsonb_build_object('ok',true,'job',jsonb_build_object(
    'id',job.id,'user_id',job.user_id,'stage',job.stage,'lease_token',job.lease_token));
end;
$$;

create function public.purge_account_data(job_id uuid, lease_token uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  job app_private.account_deletions;
  affected_pairs uuid[];
begin
  select * into job from app_private.account_deletions d where d.id = $1 and d.lease_token = $2
    and d.lease_until > clock_timestamp() and d.stage <> 'complete' for update;
  if not found then return app_private.error('lease_expired'); end if;
  if job.stage = 'auth_pending' then return '{"ok":true}'::jsonb; end if;
  select array_agg(pair_id order by pair_id) into affected_pairs from app_private.pair_members where user_id = job.user_id;
  perform 1 from app_private.pairs where id = any(affected_pairs) order by id for update;
  delete from app_private.milestone_views v where v.user_id = job.user_id
    or v.milestone_id in (select m.id from app_private.cultivation_milestones m
      join app_private.cultivations c on c.id = m.cultivation_id where c.pair_id = any(affected_pairs));
  delete from app_private.cultivation_milestones where cultivation_id in
    (select id from app_private.cultivations where pair_id = any(affected_pairs));
  delete from app_private.cultivations where pair_id = any(affected_pairs);
  delete from app_private.approvals where pair_id = any(affected_pairs);
  delete from app_private.agreements where pair_id = any(affected_pairs);
  delete from app_private.selections where pair_id = any(affected_pairs);
  delete from app_private.invitations where inviter_id = job.user_id or accepted_by = job.user_id or pair_id = any(affected_pairs);
  delete from app_private.receipts where user_id = job.user_id;
  delete from app_private.invitation_attempts where user_id = job.user_id;
  delete from app_private.pair_members where pair_id = any(affected_pairs);
  delete from app_private.pairs where id = any(affected_pairs);
  delete from app_private.profiles where user_id = job.user_id;
  update app_private.account_deletions set stage = 'auth_pending' where id = job.id;
  return '{"ok":true}'::jsonb;
end;
$$;

create function public.finish_account_deletion(job_id uuid, lease_token uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update app_private.account_deletions d
  set stage = 'complete', user_id = null, completed_at = clock_timestamp(),
      lease_token = null, lease_until = null, last_error = null
  where d.id = $1 and d.lease_token = $2 and d.lease_until > clock_timestamp() and d.stage = 'auth_pending'
    and not exists (select 1 from auth.users u where u.id = d.user_id);
  if not found then return app_private.error('deletion_incomplete'); end if;
  return '{"ok":true}'::jsonb;
end;
$$;

create function public.retry_account_deletion(job_id uuid, lease_token uuid, error_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update app_private.account_deletions d set
    lease_token = null, lease_until = null, retry_at = clock_timestamp() + interval '1 minute',
    last_error = case when $3 in ('transport','admin_auth','database') then $3 else 'transport' end
  where d.id = $1 and d.lease_token = $2 and d.stage <> 'complete';
  if not found then return app_private.error('lease_expired'); end if;
  return '{"ok":true}'::jsonb;
end;
$$;

revoke all on function app_private.end_pair(uuid), app_private.reject_deleted_member() from public, anon, authenticated, service_role;
revoke all on function public.request_account_deletion() from public, anon, service_role;
grant execute on function public.request_account_deletion() to authenticated;
revoke all on function public.claim_account_deletion(), public.purge_account_data(uuid,uuid),
  public.finish_account_deletion(uuid,uuid), public.retry_account_deletion(uuid,uuid,text)
  from public, anon, authenticated;
grant execute on function public.claim_account_deletion(), public.purge_account_data(uuid,uuid),
  public.finish_account_deletion(uuid,uuid), public.retry_account_deletion(uuid,uuid,text) to service_role;
