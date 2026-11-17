\set ON_ERROR_STOP on
-- Contrato de aceptación M3. Ejecutar sólo en una base local desechable.
begin;

do $test$
begin
  if to_regprocedure('public.get_pair_state(uuid)') is null
     or to_regprocedure('public.submit_selection(uuid,text[],integer,integer,integer,uuid)') is null
     or to_regprocedure('public.reopen_selection(uuid,integer,uuid)') is null then
    raise exception 'M3 BLOQUEADO: faltan las RPC de selección y revelación';
  end if;
end
$test$;

create function public.m3_assert(actual boolean, expected text) returns void
language plpgsql as $test$
begin
  if actual is distinct from true then raise exception 'M3 FALLÓ: %', expected; end if;
end
$test$;
grant execute on function public.m3_assert(boolean, text) to authenticated;

do $test$
declare
  member_a uuid := gen_random_uuid();
  member_b uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  pair uuid;
  invitation text := replace(gen_random_uuid()::text, '-', '');
  choices_a text[] := array['afe_carino', 'sos_respeto', 'con_escucha'];
  choices_b text[] := array['afe_ternura', 'sos_paciencia', 'con_intimidad', 'vit_juego', 'cui_apoyo'];
  operation_a uuid := gen_random_uuid();
  operation_b uuid := gen_random_uuid();
  initial_revision integer;
  shared_revision integer;
  revealed_revision integer;
  own_revision integer;
  state_a jsonb;
  state_b jsonb;
  result jsonb;
  invalid_choices text[];
begin
  insert into auth.users(id) values (member_a), (member_b), (outsider);
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', member_a::text, true);
  perform public.m3_assert((public.register_profile('Prueba A', true)->>'ok')::boolean, 'perfil A');
  perform public.m3_assert((public.create_invitation(invitation, gen_random_uuid())->>'ok')::boolean, 'invitación A');
  perform set_config('request.jwt.claim.sub', member_b::text, true);
  perform public.m3_assert((public.register_profile('Prueba B', true)->>'ok')::boolean, 'perfil B');
  pair := (public.accept_invitation(invitation, gen_random_uuid())->'pair'->>'id')::uuid;
  perform public.m3_assert(pair is not null, 'vínculo confirmado');

  state_b := public.get_pair_state(pair);
  initial_revision := (state_b->>'pair_revision')::integer;
  perform public.m3_assert(state_b->>'phase' = 'private' and initial_revision is not null, 'M3-01 fase privada inicial');

  for invalid_choices in select ids from (values
      (choices_a[1:2]), (choices_b || choices_a[1]),
      (array[choices_a[1], choices_a[1], choices_a[2]]),
      (array[choices_a[1], choices_a[2], 'id_inexistente'])
    ) as invalid(ids)
  loop
    result := public.submit_selection(pair, invalid_choices, 1, initial_revision, 0, gen_random_uuid());
    perform public.m3_assert(result->>'error' = 'validation_failed', 'M3-02 cantidad, duplicado e ID inválido');
  end loop;
  result := public.submit_selection(pair, choices_b, 999, initial_revision, 0, gen_random_uuid());
  perform public.m3_assert(result->>'error' = 'validation_failed', 'M3-02 versión de catálogo inválida');
  perform public.m3_assert((public.get_pair_state(pair)->>'pair_revision')::integer = initial_revision, 'M3-02 rechazos sin mutación');

  perform set_config('request.jwt.claim.sub', member_a::text, true);
  result := public.submit_selection(pair, choices_a, 1, initial_revision, 0, operation_a);
  perform public.m3_assert((result->>'ok')::boolean, 'M3-03 primer consentimiento');
  state_a := public.get_pair_state(pair);
  shared_revision := (state_a->>'pair_revision')::integer;
  perform public.m3_assert(state_a->'own_selection'->'quality_ids' = to_jsonb(choices_a)
    and state_a->>'phase' = 'waiting' and not (state_a ? 'reveal'), 'M3-03 A ve su elección y espera');

  perform set_config('request.jwt.claim.sub', member_b::text, true);
  state_b := public.get_pair_state(pair);
  perform public.m3_assert(state_b->>'phase' = 'private' and state_b->>'partner_shared' = 'true'
    and state_b - array['ok', 'pair_id', 'pair_revision', 'phase', 'own_selection', 'partner_shared', 'server_time', 'catalog_version'] = '{}'::jsonb
    and coalesce(state_b->'own_selection', 'null'::jsonb) = 'null'::jsonb, 'M3-03 B no recibe datos de A');
  result := public.submit_selection(pair, choices_b, 1, initial_revision, 0, gen_random_uuid());
  perform public.m3_assert(result->>'error' = 'version_conflict', 'M3-07 versión anterior rechazada');

  result := public.submit_selection(pair, choices_b, 1, shared_revision, 0, operation_b);
  perform public.m3_assert((result->>'ok')::boolean, 'M3-04 segundo consentimiento');
  state_b := public.get_pair_state(pair);
  revealed_revision := (state_b->>'pair_revision')::integer;
  perform set_config('request.jwt.claim.sub', member_a::text, true);
  state_a := public.get_pair_state(pair);
  perform public.m3_assert(state_a->>'phase' = 'revealed' and state_b->>'phase' = 'revealed'
    and state_a->'reveal' = state_b->'reveal'
    and state_a->'reveal'->'selections' @> jsonb_build_array(to_jsonb(choices_a), to_jsonb(choices_b))
    and jsonb_array_length(state_a->'reveal'->'selections') = 2
    and state_a->>'pair_revision' = state_b->>'pair_revision', 'M3-04 revelación común y vigente');

  perform set_config('request.jwt.claim.sub', outsider::text, true);
  perform public.m3_assert(public.get_pair_state(pair)->>'error' = 'pair_unavailable', 'M3-05 tercero sin lectura');
  perform public.m3_assert(public.submit_selection(pair, choices_a, 1, revealed_revision, 0, gen_random_uuid())->>'error' = 'pair_unavailable', 'M3-05 tercero sin escritura');
  perform public.m3_assert(public.reopen_selection(pair, revealed_revision, gen_random_uuid())->>'error' = 'pair_unavailable', 'M3-05 tercero no reabre');
  perform public.m3_assert(not has_function_privilege('anon', 'public.get_pair_state(uuid)', 'EXECUTE')
    and not has_schema_privilege('authenticated', 'app_private', 'USAGE'), 'M3-05 accesos alternativos cerrados');

  perform set_config('request.jwt.claim.sub', member_b::text, true);
  result := public.submit_selection(pair, choices_b, 1, shared_revision, 0, operation_b);
  perform public.m3_assert((result->>'ok')::boolean and (public.get_pair_state(pair)->>'pair_revision')::integer = revealed_revision, 'M3-06 reintento idempotente');
  result := public.submit_selection(pair, choices_a, 1, shared_revision, 0, operation_b);
  perform public.m3_assert(result->>'error' = 'operation_conflict', 'M3-06 identificador reutilizado con otro contenido');

  perform set_config('request.jwt.claim.sub', member_a::text, true);
  result := public.reopen_selection(pair, revealed_revision, gen_random_uuid());
  perform public.m3_assert((result->>'ok')::boolean, 'M3-09 reapertura explícita');
  state_a := public.get_pair_state(pair);
  perform set_config('request.jwt.claim.sub', member_b::text, true);
  state_b := public.get_pair_state(pair);
  perform public.m3_assert(state_a->>'phase' = 'private' and state_b->>'phase' = 'private'
    and state_a->>'partner_shared' = 'false' and state_b->>'partner_shared' = 'false'
    and state_a->'own_selection'->'quality_ids' = to_jsonb(choices_a)
    and state_b->'own_selection'->'quality_ids' = to_jsonb(choices_b)
    and (state_a->>'pair_revision')::integer > revealed_revision
    and not (state_a ? 'reveal') and not (state_b ? 'reveal'), 'M3-09 ambos vuelven a privado con su borrador');
  result := public.submit_selection(pair, choices_b, 1, shared_revision, 0, operation_b);
  perform public.m3_assert(not (result ? 'reveal') and not (result::text like '%afe_carino%')
    and (public.get_pair_state(pair) - 'server_time') = (state_b - 'server_time'), 'M3-06 recibo antiguo no revela ni restaura consentimiento');

  perform set_config('request.jwt.claim.sub', member_a::text, true);
  own_revision := (state_a->'own_selection'->>'revision')::integer;
  result := public.submit_selection(pair, choices_a, 1, (state_a->>'pair_revision')::integer, own_revision, gen_random_uuid());
  perform public.m3_assert((result->>'ok')::boolean and public.get_pair_state(pair)->>'phase' = 'waiting', 'M3-09 se requiere consentimiento nuevo de B');
  perform set_config('request.jwt.claim.sub', member_b::text, true);
  state_b := public.get_pair_state(pair);
  result := public.submit_selection(pair, choices_b, 1, (state_b->>'pair_revision')::integer,
    (state_b->'own_selection'->>'revision')::integer, gen_random_uuid());
  state_b := public.get_pair_state(pair);
  perform public.m3_assert((result->>'ok')::boolean and state_b->>'phase' = 'revealed'
    and (state_b->>'pair_revision')::integer > revealed_revision, 'M3-09 dos consentimientos nuevos vuelven a revelar');
end
$test$;

rollback;
\echo M3 OK: contrato SQL de selección privada y revelación bilateral.
