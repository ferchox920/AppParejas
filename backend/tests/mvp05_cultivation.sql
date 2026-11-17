\set ON_ERROR_STOP on
begin;

create function public.m5_assert(actual boolean, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from true then raise exception 'M5 FALLÓ: %', expected; end if;
end;
$$;
grant execute on function public.m5_assert(boolean, text) to authenticated;

do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  invite text := replace(gen_random_uuid()::text, '-', '');
  pair uuid;
  version integer;
  previous_version integer;
  confirmation uuid := gen_random_uuid();
  planted_id uuid;
  sprout_id uuid;
  snapshot jsonb;
  planted jsonb;
  sprouted jsonb;
  checked_at timestamptz;
begin
  insert into auth.users values (a), (b), (outsider);
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.register_profile('Prueba A', true);
  perform public.create_invitation(invite, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', b::text, true);
  perform public.register_profile('Prueba B', true);
  pair := (public.accept_invitation(invite, gen_random_uuid())->'pair'->>'id')::uuid;
  perform public.submit_selection(pair, array['afe_ternura','cui_apoyo','vit_juego'], 1, 0, 0, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.submit_selection(pair, array['afe_carino','sos_respeto','con_escucha'], 1, 1, 0, gen_random_uuid());
  perform public.update_agreement(pair, 2, 'Semilla compartida', 'Escucharnos', gen_random_uuid());
  version := (public.get_pair_state(pair)->'agreement'->>'version')::integer;
  perform public.approve_agreement(pair, version, gen_random_uuid());
  perform public.m5_assert(public.confirm_planting(pair, version, gen_random_uuid())->>'error' = 'planting_needs_approval'
    and not (public.get_pair_state(pair) ? 'planting'), 'se requieren dos aprobaciones');
  perform set_config('request.jwt.claim.sub', b::text, true);
  perform public.approve_agreement(pair, version, gen_random_uuid());
  perform public.confirm_planting(pair, version, confirmation);
  perform public.m5_assert(public.get_pair_state(pair)->'planting' = '{"own_confirmed":true,"partner_confirmed":false}'
    and not (public.get_pair_state(pair) ? 'cultivation'), 'una confirmación no siembra');
  perform public.withdraw_planting(pair, version, gen_random_uuid());
  perform public.confirm_planting(pair, version, confirmation);
  perform public.m5_assert(public.get_pair_state(pair)->'planting' = '{"own_confirmed":false,"partner_confirmed":false}',
    'repetir un recibo retirado no restaura la confirmación');
  perform public.confirm_planting(pair, version, gen_random_uuid());
  perform public.update_agreement(pair, version, 'Raíces compartidas', 'Escucharnos', gen_random_uuid());
  previous_version := version;
  snapshot := public.get_pair_state(pair)->'agreement';
  version := (snapshot->>'version')::integer;
  perform public.m5_assert(public.confirm_planting(pair, previous_version, gen_random_uuid())->>'error'
    = 'agreement_version_conflict', 'editar invalida la versión confirmada');
  perform public.approve_agreement(pair, version, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.approve_agreement(pair, version, gen_random_uuid());
  perform public.m5_assert(public.get_pair_state(pair)->'planting' = '{"own_confirmed":false,"partner_confirmed":false}',
    'una versión nueva requiere ambas confirmaciones');

  perform public.confirm_planting(pair, version, gen_random_uuid());
  perform set_config('request.jwt.claim.sub', b::text, true);
  planted_id := (public.confirm_planting(pair, version, gen_random_uuid())->>'cultivation_id')::uuid;
  planted := public.get_pair_state(pair)->'cultivation';
  perform public.m5_assert(planted_id is not null and planted->>'id' = planted_id::text
    and planted->>'name' = snapshot->>'name' and planted->>'intention' = snapshot->>'intention'
    and planted->'recipe' = snapshot->'recipe' and (planted->>'agreement_version')::integer = version
    and planted->>'stage' = 'seed'
    and (planted->>'sprout_due_at')::timestamptz - (planted->>'planted_at')::timestamptz = interval '168 hours',
    'crea una instantánea de la semilla con plazo exacto');
  perform public.m5_assert(public.get_connection_state()->'pair'->>'cultivation_available' = 'true',
    'el arranque descubre el cultivo');
  perform public.m5_assert(public.confirm_planting(pair, version, gen_random_uuid())->>'cultivation_id' = planted_id::text,
    'nueva confirmación de la misma versión recupera el cultivo');
  perform public.m5_assert(public.confirm_planting(pair, previous_version, gen_random_uuid())->>'error' = 'agreement_version_conflict',
    'una versión obsoleta no confirma un cultivo ya creado');
  perform public.m5_assert(public.withdraw_planting(pair, version, gen_random_uuid())->>'error' = 'cultivation_locked'
    and public.update_agreement(pair, version, 'Otro nombre', '', gen_random_uuid())->>'error' = 'cultivation_locked'
    and public.reopen_selection(pair, (public.get_pair_state(pair)->>'pair_revision')::integer, gen_random_uuid())->>'error'
      = 'cultivation_locked', 'sembrar congela selecciones y acuerdo');

  reset role;
  checked_at := clock_timestamp();
  update app_private.cultivations c set planted_at = checked_at - interval '168 hours' + interval '1 minute',
    sprout_due_at = checked_at + interval '1 minute' where c.id = planted_id;
  set local role authenticated;
  perform public.m5_assert(public.get_pair_state(pair)->'cultivation'->>'stage' = 'seed', 'sigue semilla justo antes del plazo');

  reset role;
  checked_at := clock_timestamp();
  update app_private.cultivations c set planted_at = checked_at - interval '168 hours',
    sprout_due_at = checked_at where c.id = planted_id;
  set local role authenticated;
  sprouted := public.get_pair_state(pair)->'cultivation';
  sprout_id := (sprouted->'first_sprout'->>'id')::uuid;
  perform public.m5_assert(sprouted->>'stage' = 'sprout' and sprout_id is not null
    and (sprouted->'first_sprout'->>'effective_at')::timestamptz = checked_at, 'el brote se registra con el vencimiento del servidor');
  perform public.mark_milestone_seen(pair, sprout_id);
  perform public.mark_milestone_seen(pair, sprout_id);
  perform public.m5_assert(public.get_pair_state(pair)->'cultivation'->'first_sprout'->>'own_seen' = 'true',
    'marcar el brote es idempotente');
  perform set_config('request.jwt.claim.sub', a::text, true);
  perform public.m5_assert(public.get_pair_state(pair)->'cultivation'->'first_sprout'
    = jsonb_build_object('id', sprout_id, 'effective_at', checked_at, 'own_seen', false),
    'misma etapa e hito, presentación por integrante');
  perform set_config('request.jwt.claim.sub', outsider::text, true);
  perform public.m5_assert(public.get_pair_state(pair) = '{"ok":false,"error":"pair_unavailable"}'
    and public.confirm_planting(pair, version, gen_random_uuid())->>'error' = 'pair_unavailable'
    and public.mark_milestone_seen(pair, sprout_id)->>'error' = 'pair_unavailable', 'una cuenta externa queda fuera');
  reset role;
  perform public.m5_assert((select count(*) from app_private.cultivations c where c.pair_id = pair) = 1
    and (select count(*) from app_private.cultivation_milestones m where m.cultivation_id = planted_id) = 1
    and (select count(*) from app_private.milestone_views v where v.milestone_id = sprout_id) = 1,
    'cultivo, hito y presentación sin duplicados');
end;
$$;

select 'M5 OK';
rollback;
