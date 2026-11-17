alter table app_private.approvals add column plant_confirmed_at timestamptz;

create table app_private.cultivations (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null unique references app_private.pairs(id),
  agreement_version integer not null,
  name text not null,
  intention text not null,
  recipe jsonb not null,
  planted_at timestamptz not null,
  sprout_due_at timestamptz not null,
  archived_at timestamptz,
  check (sprout_due_at = planted_at + interval '168 hours')
);

create table app_private.cultivation_milestones (
  id uuid primary key default gen_random_uuid(),
  cultivation_id uuid not null references app_private.cultivations(id),
  kind text not null check (kind = 'first_sprout'),
  effective_at timestamptz not null,
  created_at timestamptz not null,
  unique (cultivation_id, kind)
);

create table app_private.milestone_views (
  milestone_id uuid not null references app_private.cultivation_milestones(id),
  user_id uuid not null references auth.users(id),
  seen_at timestamptz not null default clock_timestamp(),
  primary key (milestone_id, user_id)
);

alter table app_private.cultivations enable row level security;
alter table app_private.cultivation_milestones enable row level security;
alter table app_private.milestone_views enable row level security;
revoke all on app_private.cultivations, app_private.cultivation_milestones, app_private.milestone_views
  from public, anon, authenticated;

create function app_private.lock_active_pair(target uuid) returns integer
language sql volatile set search_path = '' as $$
  select p.revision from app_private.pairs p
  where p.id = target and p.status = 'active'
    and exists (select 1 from app_private.pair_members m
                where m.pair_id = p.id and m.active and m.user_id = (select auth.uid()))
  for update;
$$;

create or replace function app_private.pair_view(pair uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'status', 'confirmed', 'demo', false, 'continued', false)
    || case when exists (select 1 from app_private.cultivations c where c.pair_id = p.id and c.archived_at is null)
         then '{"cultivation_available":true}'::jsonb else '{}'::jsonb end
  from app_private.pairs p where p.id = $1 and p.status = 'active';
$$;

-- Mantener el orden de bloqueo de M3/M4 antes de comprobar la inmutabilidad.
create function app_private.lock_unplanted_pair(target uuid) returns text
language plpgsql set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  if app_private.lock_active_pair(target) is null then return 'pair_unavailable'; end if;
  if exists (select 1 from app_private.cultivations c where c.pair_id = target) then return 'cultivation_locked'; end if;
  return null;
end;
$$;

create or replace function public.reopen_selection(pair_id uuid, expected_pair_revision integer, operation_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  blocked text := app_private.lock_unplanted_pair(pair_id);
begin
  if blocked is not null then return app_private.error(blocked); end if;
  return app_private.write_selection('reopen_selection', pair_id, null, null, expected_pair_revision, null, operation_id);
end;
$$;

create or replace function public.update_agreement(pair_id uuid, expected_agreement_version integer,
  name text, intention text, operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  blocked text := app_private.lock_unplanted_pair(pair_id);
begin
  if blocked is not null then return app_private.error(blocked); end if;
  return app_private.write_agreement('update_agreement', pair_id, expected_agreement_version, name, intention, operation_id);
end;
$$;

create function app_private.write_planting(action text, target uuid, version integer, request_id uuid)
returns jsonb language plpgsql set search_path = '' as $$
declare
  actor uuid := auth.uid();
  current app_private.agreements;
  cultivation app_private.cultivations;
  receipt app_private.receipts;
  fingerprint text;
  change_count integer;
  now_at timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  if app_private.lock_active_pair(target) is null then return app_private.error('pair_unavailable'); end if;
  if request_id is null or version is null then return app_private.error('invalid_planting'); end if;
  fingerprint := encode(extensions.digest(jsonb_build_array(target, version)::text, 'sha256'), 'hex');
  select * into receipt from app_private.receipts where user_id = actor and operation_id = request_id;
  if found and (receipt.operation <> action or receipt.payload_hash <> fingerprint) then
    return app_private.error('operation_conflict');
  end if;

  select * into cultivation from app_private.cultivations c where c.pair_id = target;
  if cultivation.id is not null then
    if cultivation.agreement_version <> version then return app_private.error('agreement_version_conflict'); end if;
    if action = 'withdraw_planting' or cultivation.archived_at is not null then
      return app_private.error('cultivation_locked');
    end if;
  elsif receipt.operation is null then
    select * into current from app_private.agreements a where a.pair_id = target;
    if not found or app_private.selection_state(target)->>'phase' <> 'revealed' then
      return app_private.error('agreement_unavailable');
    end if;
    if current.version <> version then return app_private.error('agreement_version_conflict'); end if;
    if (select count(*) from app_private.approvals a join app_private.pair_members m using (pair_id, user_id)
        where a.pair_id = target and a.agreement_version = version and m.active) <> 2 then
      return app_private.error('planting_needs_approval');
    end if;

    now_at := clock_timestamp();
    update app_private.approvals a
    set plant_confirmed_at = case when action = 'confirm_planting' then now_at else null end
    where a.pair_id = target and a.agreement_version = version and a.user_id = actor
      and (a.plant_confirmed_at is null) = (action = 'confirm_planting');
    get diagnostics change_count = row_count;

    if action = 'confirm_planting' and (select count(*) from app_private.approvals a
        join app_private.pair_members m using (pair_id, user_id)
        where a.pair_id = target and a.agreement_version = version and m.active
          and a.plant_confirmed_at is not null) = 2 then
      insert into app_private.cultivations (pair_id, agreement_version, name, intention, recipe, planted_at, sprout_due_at)
      values (target, current.version, current.name, current.intention, current.recipe, now_at, now_at + interval '168 hours')
      returning * into cultivation;
    end if;
    if change_count > 0 then
      update app_private.pairs set revision = revision + 1 where id = target;
    end if;
  end if;

  if receipt.operation is null then
    insert into app_private.receipts (user_id, operation_id, operation, payload_hash, result_id)
      values (actor, request_id, action, fingerprint, coalesce(cultivation.id, target));
  end if;
  return jsonb_build_object('ok', true)
    || case when cultivation.id is not null then jsonb_build_object('cultivation_id', cultivation.id) else '{}'::jsonb end;
end;
$$;

create function public.confirm_planting(pair_id uuid, agreement_version integer, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_planting('confirm_planting', $1, $2, $3);
$$;

create function public.withdraw_planting(pair_id uuid, agreement_version integer, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_planting('withdraw_planting', $1, $2, $3);
$$;

alter function public.get_pair_state(uuid) set schema app_private;
alter function app_private.get_pair_state(uuid) rename to agreement_state;

create function public.get_pair_state(pair_id uuid) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  base jsonb;
  cultivation app_private.cultivations;
  milestone app_private.cultivation_milestones;
  now_at timestamptz;
begin
  if app_private.lock_active_pair(pair_id) is null then return app_private.error('pair_unavailable'); end if;
  now_at := clock_timestamp();
  base := app_private.agreement_state(pair_id) || jsonb_build_object('server_time', now_at);
  select * into cultivation from app_private.cultivations c where c.pair_id = $1 and c.archived_at is null;
  if not found then
    if base->'agreement'->'own_approved' = 'true'::jsonb and base->'agreement'->'partner_approved' = 'true'::jsonb then
      return base || (select jsonb_build_object('planting', jsonb_build_object(
        'own_confirmed', bool_or(a.user_id = actor and a.plant_confirmed_at is not null),
        'partner_confirmed', bool_or(a.user_id <> actor and a.plant_confirmed_at is not null)))
        from app_private.approvals a join app_private.pair_members m using (pair_id, user_id)
        where a.pair_id = $1 and a.agreement_version = (base->'agreement'->>'version')::integer and m.active);
    end if;
    return base;
  end if;

  if cultivation.sprout_due_at <= now_at then
    insert into app_private.cultivation_milestones (cultivation_id, kind, effective_at, created_at)
      values (cultivation.id, 'first_sprout', cultivation.sprout_due_at, now_at)
      on conflict (cultivation_id, kind) do nothing;
  end if;
  select * into milestone from app_private.cultivation_milestones m
    where m.cultivation_id = cultivation.id and m.kind = 'first_sprout';

  return base || jsonb_build_object('cultivation', jsonb_build_object(
    'id', cultivation.id, 'agreement_version', cultivation.agreement_version,
    'name', cultivation.name, 'intention', cultivation.intention, 'recipe', cultivation.recipe,
    'planted_at', cultivation.planted_at, 'sprout_due_at', cultivation.sprout_due_at,
    'remaining_seconds', greatest(0, ceil(extract(epoch from cultivation.sprout_due_at - now_at))),
    'stage', case when milestone.id is not null then 'sprout' else 'seed' end,
    'first_sprout', case when milestone.id is not null then jsonb_build_object(
      'id', milestone.id, 'effective_at', milestone.effective_at,
      'own_seen', exists (select 1 from app_private.milestone_views v
                          where v.milestone_id = milestone.id and v.user_id = actor)) end
  ));
end;
$$;

create function public.mark_milestone_seen(pair_id uuid, milestone_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if app_private.lock_active_pair(pair_id) is null then return app_private.error('pair_unavailable'); end if;
  if not exists (select 1 from app_private.cultivation_milestones m
    join app_private.cultivations c on c.id = m.cultivation_id
    where m.id = $2 and c.pair_id = $1 and c.archived_at is null) then
    return app_private.error('milestone_unavailable');
  end if;
  insert into app_private.milestone_views (milestone_id, user_id) values ($2, auth.uid())
    on conflict on constraint milestone_views_pkey do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function app_private.lock_active_pair(uuid), app_private.lock_unplanted_pair(uuid),
  app_private.write_planting(text, uuid, integer, uuid), app_private.agreement_state(uuid)
  from public, anon, authenticated;
revoke all on function public.get_pair_state(uuid), public.confirm_planting(uuid, integer, uuid),
  public.withdraw_planting(uuid, integer, uuid), public.mark_milestone_seen(uuid, uuid) from public, anon;
grant execute on function public.get_pair_state(uuid), public.confirm_planting(uuid, integer, uuid),
  public.withdraw_planting(uuid, integer, uuid), public.mark_milestone_seen(uuid, uuid) to authenticated;
