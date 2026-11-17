\set ON_ERROR_STOP on
begin;

create function public.m4_assert(actual boolean, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from true then raise exception 'M4 FALLÓ: %', expected; end if;
end;
$$;
grant execute on function public.m4_assert(boolean, text) to authenticated;

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  invitation text := replace(gen_random_uuid()::text, '-', '');
  pair uuid;
  a_ids text[] := array['afe_carino', 'sos_respeto', 'con_escucha'];
  b_ids text[] := array['afe_carino', 'afe_ternura', 'sos_paciencia', 'vit_juego', 'cui_apoyo'];
  state jsonb;
  recipe jsonb;
  old_version integer;
  current_version integer;
  approval_id uuid := gen_random_uuid();
  edit_id uuid := gen_random_uuid();
  revision integer;
  seed_name text := repeat('👩🏽‍🌾', 29) || U&'a\0301';
begin
  perform public.m4_assert(app_private.grapheme_count(seed_name) = 30, 'límites medidos en grafemas');
  insert into auth.users(id) values (a), (b), (c);
  set local role authenticated;

  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.register_profile('Prueba A', true);
  perform public.create_invitation(invitation, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', b::text, true);
  perform public.register_profile('Prueba B', true);
  pair := (public.accept_invitation(invitation, gen_random_uuid())->'pair'->>'id')::uuid;
  perform public.m4_assert(not (public.get_pair_state(pair) ? 'agreement'), 'sin receta antes de compartir');

  perform public.submit_selection(pair, b_ids, 1, 0, 0, gen_random_uuid());
  perform public.m4_assert(not (public.get_pair_state(pair) ? 'agreement'), 'sin receta con un solo consentimiento');
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.submit_selection(pair, a_ids, 1, 1, 0, gen_random_uuid());
  state := public.get_pair_state(pair)->'agreement';
  recipe := state->'recipe';
  current_version := (state->>'version')::integer;
  perform public.m4_assert(recipe->'selected_union' ?& array['afe_carino', 'sos_respeto', 'con_escucha',
    'afe_ternura', 'sos_paciencia', 'vit_juego', 'cui_apoyo'], 'la receta conserva todos los aportes');
  perform public.m4_assert(abs((recipe->'weights'->>'afe_carino')::numeric - 4::numeric / 15) < 1e-16
    and abs((recipe->'weights'->>'sos_respeto')::numeric - 1::numeric / 6) < 1e-16
    and (recipe->'weights'->>'vit_juego')::numeric = 0.1, 'mitad del aporte por integrante');
  perform public.m4_assert(public.approve_agreement(pair, current_version, gen_random_uuid())->>'error'
    = 'invalid_agreement', 'para aprobar se requiere un nombre');
  perform public.m4_assert(public.update_agreement(pair, current_version, 'a', '', gen_random_uuid())->>'error'
    = 'invalid_agreement', 'nombre demasiado corto');
  perform public.m4_assert(public.update_agreement(pair, current_version, seed_name || 'a', '', gen_random_uuid())->>'error'
    = 'invalid_agreement', 'nombre demasiado largo');
  perform public.m4_assert(public.update_agreement(pair, current_version, 'Semilla', repeat('🇦🇷', 121), gen_random_uuid())->>'error'
    = 'invalid_agreement', 'intención demasiado larga');
  perform public.m4_assert(public.update_agreement(pair, current_version, 'Semilla', chr(9), gen_random_uuid())->>'error'
    = 'invalid_agreement', 'carácter de control rechazado');
  perform public.m4_assert(public.update_agreement(pair, current_version, U&'\00A0' || seed_name || ' ',
    repeat('🇦🇷', 120), edit_id) = '{"ok":true}', 'acepta límites de grafemas y recorta espacios');
  perform public.m4_assert(public.update_agreement(pair, current_version, U&'\00A0' || seed_name || ' ',
    repeat('🇦🇷', 120), edit_id) = '{"ok":true}', 'reintento de la edición con el mismo identificador');
  old_version := current_version;
  state := public.get_pair_state(pair)->'agreement';
  current_version := (state->>'version')::integer;
  perform public.m4_assert(current_version = old_version + 1 and state->>'name' = normalize(seed_name)
    and state->'recipe' = recipe, 'normaliza, avanza una vez y mantiene la receta al editar');

  perform public.m4_assert(public.approve_agreement(pair, current_version, approval_id) = '{"ok":true}',
    'primera aprobación');
  state := public.get_pair_state(pair)->'agreement';
  perform public.m4_assert((state->>'own_approved')::boolean and not (state->>'partner_approved')::boolean,
    'A ve su aprobación');
  perform set_config('request.jwt.claim.sub', b::text, true);
  state := public.get_pair_state(pair)->'agreement';
  perform public.m4_assert(not (state->>'own_approved')::boolean and (state->>'partner_approved')::boolean
    and state->'recipe' = recipe, 'B ve la primera aprobación y la misma receta');
  perform public.m4_assert(public.approve_agreement(pair, current_version, gen_random_uuid()) = '{"ok":true}',
    'segunda aprobación sobre la misma versión');
  state := public.get_pair_state(pair);
  perform public.m4_assert((state->'agreement'->>'own_approved')::boolean
    and (state->'agreement'->>'partner_approved')::boolean, 'las dos aprobaciones son visibles');

  revision := (state->>'pair_revision')::integer;
  perform public.approve_agreement(pair, current_version, gen_random_uuid());
  perform public.m4_assert((public.get_pair_state(pair)->>'pair_revision')::integer = revision,
    'aprobar de nuevo no cambia el estado');
  perform public.update_agreement(pair, current_version, 'Nueva semilla', '', gen_random_uuid());
  state := public.get_pair_state(pair)->'agreement';
  perform public.m4_assert(not (state->>'own_approved')::boolean and not (state->>'partner_approved')::boolean,
    'la edición retira ambas aprobaciones');
  perform public.m4_assert(public.approve_agreement(pair, current_version, gen_random_uuid())->>'error'
    = 'agreement_version_conflict', 'rechaza aprobación de una versión antigua');
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.m4_assert(public.approve_agreement(pair, current_version, approval_id) = '{"ok":true}'
    and not (public.get_pair_state(pair)->'agreement'->>'own_approved')::boolean,
    'un recibo antiguo no vuelve a aprobar');

  state := public.get_pair_state(pair);
  revision := (state->>'pair_revision')::integer;
  perform public.reopen_selection(pair, revision, gen_random_uuid());
  perform public.m4_assert(not (public.get_pair_state(pair) ? 'agreement'), 'reapertura oculta acuerdo y receta');
  perform public.submit_selection(pair, array[a_ids[3], a_ids[1], a_ids[2]], 1, revision + 1, 1, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', b::text, true);
  perform public.submit_selection(pair, array[b_ids[5], b_ids[4], b_ids[3], b_ids[2], b_ids[1]], 1,
    revision + 2, 1, gen_random_uuid());
  state := public.get_pair_state(pair)->'agreement';
  perform public.m4_assert(state->'recipe' = recipe and (state->>'version')::integer > current_version
    and state->>'name' = '' and not (state->>'own_approved')::boolean and not (state->>'partner_approved')::boolean,
    'revelar en otro orden genera la misma receta y un acuerdo nuevo');
  perform set_config('request.jwt.claim.sub', c::text, true);
  perform public.m4_assert(public.get_pair_state(pair) = '{"ok":false,"error":"pair_unavailable"}'
    and public.approve_agreement(pair, (state->>'version')::integer, gen_random_uuid())->>'error' = 'pair_unavailable'
    and public.update_agreement(pair, (state->>'version')::integer, 'Intruso', '', gen_random_uuid())->>'error'
      = 'pair_unavailable', 'C no puede leer, editar ni aprobar');
end;
$$;

select 'M4 OK';
rollback;
