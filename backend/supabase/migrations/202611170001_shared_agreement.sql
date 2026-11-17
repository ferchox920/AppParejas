create table app_private.agreements (
  pair_id uuid primary key references app_private.pairs(id),
  version integer not null check (version > 0),
  selection_revisions jsonb not null,
  recipe jsonb not null,
  name text not null default '',
  intention text not null default '',
  unique (pair_id, version)
);

create table app_private.approvals (
  pair_id uuid not null,
  agreement_version integer not null,
  user_id uuid not null,
  approved_at timestamptz not null default statement_timestamp(),
  primary key (pair_id, agreement_version, user_id),
  foreign key (pair_id, agreement_version) references app_private.agreements(pair_id, version) on delete cascade,
  foreign key (pair_id, user_id) references app_private.pair_members(pair_id, user_id)
);

alter table app_private.agreements enable row level security;
alter table app_private.approvals enable row level security;
revoke all on app_private.agreements, app_private.approvals from public, anon, authenticated;

create function app_private.sync_agreement(target uuid, version integer) returns void
language plpgsql set search_path = '' as $$
declare
  revisions jsonb;
  recipe jsonb;
begin
  select jsonb_agg(s.revision order by s.user_id) into revisions
  from app_private.selections s
  join app_private.pair_members m using (pair_id, user_id)
  where s.pair_id = target and m.active and s.shared
  having count(*) = 2;

  if revisions is null then
    delete from app_private.agreements a where a.pair_id = target;
    return;
  end if;
  if exists (select 1 from app_private.agreements a
             where a.pair_id = target and a.selection_revisions = revisions) then return; end if;

  -- Ciento veinte unidades exactas. Cada integrante distribuye sesenta.
  with qualities as (
    select q.id, sum(60 / cardinality(s.quality_ids)) as units
    from app_private.selections s
    join app_private.pair_members m using (pair_id, user_id)
    cross join lateral unnest(s.quality_ids) q(id)
    where s.pair_id = target and m.active and s.shared
    group by q.id
  ), families as (
    select split_part(id, '_', 1) as id, sum(units) as units from qualities group by 1
  )
  select jsonb_build_object(
    'catalog_version', 1, 'recipe_version', 'shared-1', 'asset_version', 'primitive-1',
    'selected_union', jsonb_agg(id order by id collate "C"),
    'weights', jsonb_object_agg(id, units::numeric / 120),
    'family_weights', (select jsonb_object_agg(id, units / 120) from families),
    'identity', encode(extensions.digest('shared-1|primitive-1|1|' ||
      string_agg(id || ':' || units, ';' order by id collate "C"), 'sha256'), 'hex')
  ) into recipe from qualities;

  delete from app_private.agreements a where a.pair_id = target;
  insert into app_private.agreements (pair_id, version, selection_revisions, recipe)
    values (target, version, revisions, recipe);
end;
$$;

create function app_private.sync_agreement_on_pair_revision() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform app_private.sync_agreement(new.id, new.revision);
  return new;
end;
$$;

create trigger sync_agreement_on_pair_revision after update of revision on app_private.pairs
for each row when (new.status = 'active' and old.revision is distinct from new.revision)
execute function app_private.sync_agreement_on_pair_revision();

-- Las parejas que ya revelaron M3 reciben el mismo acuerdo al migrar.
do $$
declare
  pair record;
begin
  for pair in select p.id, p.revision from app_private.pairs p where p.status = 'active'
  loop
    perform app_private.sync_agreement(pair.id, pair.revision);
  end loop;
end;
$$;

alter function public.get_pair_state(uuid) set schema app_private;
alter function app_private.get_pair_state(uuid) rename to selection_state;

create function public.get_pair_state(pair_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select base.value || coalesce((
    select jsonb_build_object('agreement', jsonb_build_object(
      'version', a.version, 'name', a.name, 'intention', a.intention, 'recipe', a.recipe,
      'own_approved', coalesce(flags.own_approved, false),
      'partner_approved', coalesce(flags.partner_approved, false)
    ))
    from app_private.agreements a
    cross join lateral (
      select bool_or(p.user_id = (select auth.uid())) as own_approved,
             bool_or(p.user_id <> (select auth.uid())) as partner_approved
      from app_private.approvals p
      join app_private.pair_members m using (pair_id, user_id)
      where p.pair_id = a.pair_id and p.agreement_version = a.version and m.active
    ) flags
    where a.pair_id = $1 and base.value->>'phase' = 'revealed'
  ), '{}'::jsonb)
  from (select app_private.selection_state($1) as value) base;
$$;

create function app_private.write_agreement(
  action text, target uuid, expected_version integer, proposed_name text,
  proposed_intention text, request_id uuid
) returns jsonb
language plpgsql set search_path = '' as $$
declare
  actor uuid := auth.uid();
  pair_revision integer;
  current app_private.agreements;
  receipt app_private.receipts;
  fingerprint text;
  changed_rows integer := 0;
  outer_spaces constant text := U&' \00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\202F\205F\3000';
begin
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  select p.revision into pair_revision
  from app_private.pairs p
  where p.id = target and p.status = 'active'
    and exists (select 1 from app_private.pair_members m
                where m.pair_id = target and m.user_id = actor and m.active)
  for update;
  if not found then return app_private.error('pair_unavailable'); end if;
  if request_id is null or expected_version is null then return app_private.error('invalid_agreement'); end if;

  fingerprint := encode(extensions.digest(
    jsonb_build_array(target, expected_version, proposed_name, proposed_intention)::text, 'sha256'), 'hex');
  select * into receipt from app_private.receipts where user_id = actor and operation_id = request_id;
  if found then
    if receipt.operation <> action or receipt.payload_hash <> fingerprint then
      return app_private.error('operation_conflict');
    end if;
    return jsonb_build_object('ok', true);
  end if;

  select * into current from app_private.agreements a where a.pair_id = target;
  if not found or app_private.selection_state(target)->>'phase' <> 'revealed' then
    return app_private.error('agreement_unavailable');
  end if;
  if current.version <> expected_version then return app_private.error('agreement_version_conflict'); end if;

  if action = 'update_agreement' then
    if proposed_name is null or proposed_intention is null
       or octet_length(proposed_name) > 4096 or octet_length(proposed_intention) > 16384
       or proposed_name collate "C" ~ U&'[\0001-\001F\007F-\009F\2028\2029]'
       or proposed_intention collate "C" ~ U&'[\0001-\001F\007F-\009F\2028\2029]' then
      return app_private.error('invalid_agreement');
    end if;
    proposed_name := normalize(btrim(proposed_name, outer_spaces));
    proposed_intention := normalize(btrim(proposed_intention, outer_spaces));
    if app_private.grapheme_count(proposed_name) not between 2 and 30
       or app_private.grapheme_count(proposed_intention) > 120 then
      return app_private.error('invalid_agreement');
    end if;
    if (proposed_name, proposed_intention) is distinct from (current.name, current.intention) then
      delete from app_private.approvals p where p.pair_id = target;
      update app_private.agreements a set version = pair_revision + 1,
        name = proposed_name, intention = proposed_intention where a.pair_id = target;
      changed_rows := 1;
    end if;
  else
    if current.name = '' then return app_private.error('invalid_agreement'); end if;
    insert into app_private.approvals (pair_id, agreement_version, user_id)
      values (target, current.version, actor) on conflict do nothing;
    get diagnostics changed_rows = row_count;
  end if;

  if changed_rows > 0 then
    update app_private.pairs set revision = pair_revision + 1 where id = target;
  end if;
  insert into app_private.receipts (user_id, operation_id, operation, payload_hash, result_id)
    values (actor, request_id, action, fingerprint, target);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.update_agreement(pair_id uuid, expected_agreement_version integer,
  name text, intention text, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_agreement('update_agreement', $1, $2, $3, $4, $5);
$$;

create function public.approve_agreement(pair_id uuid, agreement_version integer, operation_id uuid) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.write_agreement('approve_agreement', $1, $2, null, null, $3);
$$;

revoke all on function app_private.sync_agreement(uuid, integer), app_private.sync_agreement_on_pair_revision(),
  app_private.selection_state(uuid), app_private.write_agreement(text, uuid, integer, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.get_pair_state(uuid), public.update_agreement(uuid, integer, text, text, uuid),
  public.approve_agreement(uuid, integer, uuid) from public, anon;
grant execute on function public.get_pair_state(uuid), public.update_agreement(uuid, integer, text, text, uuid),
  public.approve_agreement(uuid, integer, uuid) to authenticated;
