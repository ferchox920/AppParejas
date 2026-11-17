\set ON_ERROR_STOP on
begin;

insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
select public.register_profile('Sol', true);
select public.create_invitation(repeat('a', 32), '10000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select public.register_profile('Luz', true);
select public.accept_invitation(repeat('a', 32), '10000000-0000-0000-0000-000000000002')->'pair'->>'id' as pair_id \gset
select set_config('test.pair_id', :'pair_id', true);

do $$
declare
  pair uuid := current_setting('test.pair_id')::uuid;
  expected jsonb := '{"ok":true,"phase":"private","pair_revision":0,"catalog_version":1,"own_selection":null,"partner_shared":false}';
begin
  if (public.get_pair_state(pair) - 'server_time') is distinct from expected then
    raise exception 'B debe recibir la fase privada inicial';
  end if;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
  if (public.get_pair_state(pair) - 'server_time') is distinct from expected then
    raise exception 'A debe recibir la misma revisión inicial';
  end if;

  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
  if public.get_pair_state(pair) is distinct from '{"ok":false,"error":"pair_unavailable"}'::jsonb then
    raise exception 'C debe quedar fuera del vínculo';
  end if;

  if has_function_privilege('anon', 'public.get_pair_state(uuid)', 'EXECUTE')
    or has_schema_privilege('authenticated', 'app_private', 'USAGE') then
    raise exception 'Las vías de acceso alternativas deben estar cerradas';
  end if;
end;
$$;

reset role;
update app_private.pair_members set active = false
where pair_id = :'pair_id' and user_id = '00000000-0000-0000-0000-000000000002';
set local role authenticated;
do $$
begin
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
  if public.get_pair_state(current_setting('test.pair_id')::uuid)->>'error' is distinct from 'pair_unavailable' then
    raise exception 'Una membresía inactiva debe quedar fuera del vínculo';
  end if;
end;
$$;

rollback;
\echo M3 ENTRADA OK
