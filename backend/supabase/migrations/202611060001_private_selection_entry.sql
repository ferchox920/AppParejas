alter table app_private.pairs
  add column revision integer not null default 0;

create function public.get_pair_state(pair_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select jsonb_build_object(
      'ok', true,
      'phase', 'private',
      'pair_revision', p.revision,
      'catalog_version', 1,
      'own_selection', null,
      'partner_shared', false,
      'server_time', statement_timestamp()
    )
    from app_private.pairs p
    join app_private.pair_members m on m.pair_id = p.id
    where p.id = $1 and p.status = 'active'
      and m.user_id = auth.uid() and m.active
  ), app_private.error('pair_unavailable'));
$$;

revoke all on function public.get_pair_state(uuid) from public, anon;
grant execute on function public.get_pair_state(uuid) to authenticated;
