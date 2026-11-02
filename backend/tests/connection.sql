\set ON_ERROR_STOP on
begin;
create function public.test_assert(value boolean, message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'TEST: %', message; end if; end;
$$;
grant execute on function public.test_assert(boolean, text) to authenticated;
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003'),
 ('00000000-0000-0000-0000-000000000004');
set role authenticated;
select set_config('request.jwt.claim.sub', '', false);
select test_assert(get_connection_state()->>'error' = 'auth', 'Sin identidad no hay estado');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select test_assert(register_profile('Sol', false)->>'error' = 'consent', 'Consentimiento necesario');
select test_assert(register_profile(E'So\nl', true)->>'error' = 'name', 'Rechazar controles');
select test_assert((register_profile('Sol', true)->>'ok')::boolean, 'Perfil del invitante');
select test_assert((create_invitation(repeat('a',32),'10000000-0000-0000-0000-000000000001')->>'ok')::boolean, 'Crear invitación');
select test_assert((create_invitation(repeat('a',32),'10000000-0000-0000-0000-000000000001')->>'ok')::boolean, 'Reintento de creación');
select test_assert(create_invitation(repeat('b',32),'10000000-0000-0000-0000-000000000001')->>'error' = 'operation_conflict', 'No reutilizar operación con distinto token');
select test_assert(resolve_invitation(repeat('a',32))->>'error' = 'self_invitation', 'No aceptar invitación propia');
select test_assert(get_connection_state()->'pair' is null, 'Crear no vincula');
select test_assert(get_connection_state()->'invitation'->>'pin' = '', 'Consulta no devuelve token');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
select test_assert((register_profile('Luz', true)->>'ok')::boolean, 'Perfil receptor');
select test_assert((resolve_invitation(repeat('a',32))->>'ok')::boolean, 'Revisar invitación');
select test_assert(get_connection_state()->'pair' is null, 'Resolver no vincula');
select test_assert((accept_invitation(repeat('a',32),'20000000-0000-0000-0000-000000000001')->>'ok')::boolean, 'Aceptar crea vínculo');
select get_connection_state()->'pair'->>'id' as expected_pair \gset
select test_assert(accept_invitation(repeat('a',32),'20000000-0000-0000-0000-000000000001')->'pair'->>'id' = :'expected_pair', 'Respuesta perdida no duplica vínculo');
select test_assert(create_invitation(repeat('c',32),'20000000-0000-0000-0000-000000000002')->>'error' = 'already_linked', 'Un vínculo activo por cuenta');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select test_assert(get_connection_state()->'pair'->>'id' = :'expected_pair', 'Ambos recuperan el mismo vínculo');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', false);
select register_profile('Mar', true);
select test_assert(get_connection_state()->'pair' is null, 'Tercera cuenta sin acceso');
select test_assert(accept_invitation(repeat('a',32),'30000000-0000-0000-0000-000000000001')->>'error' = 'invalid_pin', 'Token usado no sirve a tercero');
select test_assert(not has_schema_privilege('authenticated','app_private','USAGE'), 'Esquema privado sin acceso');
reset role;
select test_assert(not has_table_privilege('authenticated','app_private.pair_members','SELECT'), 'Sin ruta de lectura directa');
select test_assert(not has_function_privilege('anon','public.accept_invitation(text,uuid)','EXECUTE'), 'Anónimo sin operaciones');
set role authenticated;
select create_invitation(repeat('d',32),'30000000-0000-0000-0000-000000000002')->'invitation'->>'id' as cancelled_id \gset
select test_assert((cancel_invitation(:'cancelled_id','30000000-0000-0000-0000-000000000003')->>'ok')::boolean, 'Cancelación');
select test_assert((cancel_invitation(:'cancelled_id','30000000-0000-0000-0000-000000000003')->>'ok')::boolean, 'Cancelación idempotente');
select create_invitation(repeat('e',32),'30000000-0000-0000-0000-000000000004');
reset role;
update app_private.invitations set expires_at = now() - interval '1 second' where token_hash = encode(extensions.digest(repeat('e',32),'sha256'),'hex');
select test_assert((select count(*) = 1 from app_private.pairs), 'Una sola pareja persistida');
select test_assert((select count(*) = 2 from app_private.pair_members where active), 'Exactamente dos integrantes');
select test_assert(not exists(select 1 from app_private.invitations where token_hash = repeat('a',32)), 'No guardar token original');
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000004', false);
select register_profile('Rio', true);
select test_assert(resolve_invitation(repeat('d',32))->>'error' = 'invalid_pin', 'Invitación cancelada inaccesible');
select test_assert(resolve_invitation(repeat('e',32))->>'error' = 'invalid_pin', 'Invitación vencida inaccesible');
select resolve_invitation(repeat('f',32)) from generate_series(1,13);
select test_assert(resolve_invitation(repeat('f',32))->>'error' = 'rate_limited', 'Límite de intentos');
reset role;
rollback;
\echo BACKEND: comprobaciones de identidad, privacidad, reintentos y vencimiento aprobadas.
