create table app_private.selections (
  pair_id uuid not null,
  user_id uuid not null,
  quality_ids text[] not null,
  revision integer not null check (revision > 0),
  shared boolean not null,
  primary key (pair_id, user_id),
  foreign key (pair_id, user_id) references app_private.pair_members(pair_id, user_id)
);
alter table app_private.selections enable row level security;
revoke all on app_private.selections from public, anon, authenticated;

create or replace function public.get_pair_state(pair_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object(
      'ok', true,
      'phase', case when not coalesce(own.shared, false) then 'private'
                    when shared.total = 2 then 'revealed' else 'waiting' end,
      'pair_revision', p.revision,
      'catalog_version', 1,
      'own_selection', case when own.user_id is not null then
        jsonb_build_object('quality_ids', own.quality_ids, 'revision', own.revision) end,
      'partner_shared', shared.total > case when own.shared then 1 else 0 end,
      'server_time', statement_timestamp()
    ) || case when own.shared and shared.total = 2 then
      jsonb_build_object('reveal', jsonb_build_object('selections', shared.choices))
      else '{}'::jsonb end
    from app_private.pairs p
    join app_private.pair_members actor on actor.pair_id = p.id
      and actor.user_id = (select auth.uid()) and actor.active
    left join app_private.selections own on own.pair_id = p.id and own.user_id = actor.user_id
    cross join lateral (
      select count(*) as total, jsonb_agg(s.quality_ids order by s.user_id) as choices
      from app_private.selections s
      join app_private.pair_members m using (pair_id, user_id)
      where s.pair_id = p.id and m.active and s.shared
    ) shared
    where p.id = $1 and p.status = 'active'
  ), app_private.error('pair_unavailable'));
$$;

create function app_private.write_selection(
  action text, target uuid, ids text[], version integer,
  expected_pair integer, expected_selection integer, request_id uuid
) returns jsonb
language plpgsql set search_path = '' as $$
declare
  actor uuid := auth.uid();
  current_pair integer;
  own app_private.selections;
  receipt app_private.receipts;
  fingerprint text;
begin
  -- Serializar recibos del actor y mutaciones de los dos miembros del vínculo.
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  select p.revision into current_pair
  from app_private.pairs p
  where p.id = target and p.status = 'active'
    and exists (select 1 from app_private.pair_members m
      where m.pair_id = p.id and m.user_id = actor and m.active)
  for update;
  if not found then return app_private.error('pair_unavailable'); end if;

  if request_id is null or expected_pair is null then
    return app_private.error('validation_failed');
  end if;
  fingerprint := encode(extensions.digest(
    jsonb_build_array(target, ids, version, expected_pair, expected_selection)::text, 'sha256'), 'hex');
  select * into receipt from app_private.receipts
    where user_id = actor and operation_id = request_id;
  if found then
    if receipt.operation <> action or receipt.payload_hash <> fingerprint then
      return app_private.error('operation_conflict');
    end if;
    -- El recibo confirma la ejecución histórica. La proyección se consulta aparte.
    return jsonb_build_object('ok', true);
  end if;

  if expected_pair <> current_pair then return app_private.error('version_conflict'); end if;
  select * into own from app_private.selections where pair_id = target and user_id = actor;
  if action = 'submit_selection' then
    if not app_private.valid_selection(ids, version) or expected_selection is null then
      return app_private.error('validation_failed');
    end if;
    if expected_selection <> coalesce(own.revision, 0) or own.shared then
      return app_private.error('version_conflict');
    end if;
    insert into app_private.selections (pair_id, user_id, quality_ids, revision, shared)
    values (target, actor, ids, coalesce(own.revision, 0) + 1, true)
    on conflict (pair_id, user_id) do update
      set quality_ids = excluded.quality_ids, revision = excluded.revision, shared = true;
  else
    if not coalesce(own.shared, false) then return app_private.error('version_conflict'); end if;
    update app_private.selections set shared = false where pair_id = target and shared;
  end if;
  update app_private.pairs set revision = revision + 1 where id = target;
  insert into app_private.receipts (user_id, operation_id, operation, payload_hash, result_id)
    values (actor, request_id, action, fingerprint, target);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.submit_selection(pair_id uuid, quality_ids text[], catalog_version integer,
  expected_pair_revision integer, expected_selection_revision integer, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_selection('submit_selection', $1, $2, $3, $4, $5, $6);
$$;

create function public.reopen_selection(pair_id uuid, expected_pair_revision integer, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_selection('reopen_selection', $1, null, null, $2, null, $3);
$$;

revoke all on function app_private.write_selection(text, uuid, text[], integer, integer, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.get_pair_state(uuid), public.submit_selection(uuid, text[], integer, integer, integer, uuid),
  public.reopen_selection(uuid, integer, uuid) from public, anon;
grant execute on function public.get_pair_state(uuid), public.submit_selection(uuid, text[], integer, integer, integer, uuid),
  public.reopen_selection(uuid, integer, uuid) to authenticated;
