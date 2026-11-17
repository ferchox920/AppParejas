\set ON_ERROR_STOP on
begin;
create function public.m6_assert(actual boolean, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from true then raise exception 'M6 FALLÓ: %', expected; end if;
end;
$$;
grant execute on function public.m6_assert(boolean,text) to authenticated, service_role;
do $$
declare
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  invite text := replace(gen_random_uuid()::text,'-','');
  pair uuid;
  revision integer;
  version integer;
  operation uuid := gen_random_uuid();
  first_receipt uuid := gen_random_uuid();
  result jsonb;
  job jsonb;
begin
  insert into auth.users values(a),(b),(c);
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.register_profile('Prueba A',true);
  perform public.create_invitation(invite,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.register_profile('Prueba B',true);
  pair := (public.accept_invitation(invite,gen_random_uuid())->'pair'->>'id')::uuid;
  perform public.submit_selection(pair,array['afe_carino','sos_respeto','con_escucha'],1,0,0,first_receipt);
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.submit_selection(pair,array['afe_ternura','cui_apoyo','vit_juego'],1,1,0,gen_random_uuid());
  perform public.update_agreement(pair,2,'Prueba semilla','',gen_random_uuid());
  version := (public.get_pair_state(pair)->'agreement'->>'version')::integer;
  perform public.approve_agreement(pair,version,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.approve_agreement(pair,version,gen_random_uuid());
  perform public.confirm_planting(pair,version,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.confirm_planting(pair,version,gen_random_uuid());
  revision := (public.get_pair_state(pair)->>'pair_revision')::integer;

  perform set_config('request.jwt.claim.sub',c::text,true);
  perform public.m6_assert(public.end_pair(pair,revision,gen_random_uuid())->>'error'='pair_unavailable',
    'una tercera cuenta no puede desvincular');
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.m6_assert(public.end_pair(pair,revision-1,gen_random_uuid())->>'error'='version_conflict',
    'revisión obsoleta pide consultar antes de salir');
  perform public.m6_assert(public.end_pair(pair,revision,operation)='{"ok":true}'::jsonb
    and public.end_pair(pair,revision,operation)='{"ok":true}'::jsonb,
    'desvinculación unilateral e idempotente');
  perform public.m6_assert(public.get_pair_state(pair)->>'error'='pair_unavailable'
    and not(public.get_connection_state() ? 'pair'),'el iniciador pierde el acceso');
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.m6_assert(public.get_pair_state(pair)->>'error'='pair_unavailable'
    and public.confirm_planting(pair,version,gen_random_uuid())->>'error'='pair_unavailable'
    and public.submit_selection(pair,array['afe_carino','sos_respeto','con_escucha'],1,0,0,first_receipt)->>'error'='pair_unavailable',
    'la pareja y los recibos previos no recuperan el contenido');
  reset role;
  perform public.m6_assert((select archived_at is not null from app_private.cultivations where pair_id=pair)
    and not exists(select 1 from app_private.pair_members where pair_id=pair and active),
    'cultivo archivado y ambas membresías revocadas');

  set local role authenticated;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.m6_assert(public.request_account_deletion()='{"ok":true,"deletion_requested":true}'::jsonb
    and public.request_account_deletion()='{"ok":true,"deletion_requested":true}'::jsonb,'solicitud de baja repetible');
  perform public.m6_assert(public.get_connection_state()->>'error'='account_deleting'
    and public.register_profile('Otra identidad',true)->>'error'='account_deleting'
    and public.create_invitation(invite,gen_random_uuid())->>'error'='account_deleting',
    'un JWT pendiente de vencer queda bloqueado en todas las operaciones');
  begin
    perform public.claim_account_deletion();
    raise exception 'claim abierto a authenticated';
  exception when insufficient_privilege then null;
  end;
  set local role service_role;
  job := public.claim_account_deletion()->'job';
  perform public.m6_assert(job->>'user_id'=a::text and public.claim_account_deletion()->'job'='null'::jsonb,
    'un trabajador reclama y otro no recibe la misma tarea');
  perform public.m6_assert(public.purge_account_data((job->>'id')::uuid,gen_random_uuid())->>'error'='lease_expired',
    'una concesión incorrecta no borra');
  perform public.m6_assert(public.purge_account_data((job->>'id')::uuid,(job->>'lease_token')::uuid)='{"ok":true}'::jsonb
    and public.purge_account_data((job->>'id')::uuid,(job->>'lease_token')::uuid)='{"ok":true}'::jsonb,
    'purga reintentable');
  perform public.m6_assert(public.finish_account_deletion((job->>'id')::uuid,(job->>'lease_token')::uuid)->>'error'='deletion_incomplete',
    'no se declara completada mientras Auth conserva la identidad');
  perform public.retry_account_deletion((job->>'id')::uuid,(job->>'lease_token')::uuid,'admin_auth');
  reset role;
  perform public.m6_assert(not exists(select 1 from app_private.cultivations where pair_id=pair)
    and not exists(select 1 from app_private.selections where pair_id=pair)
    and not exists(select 1 from app_private.profiles where user_id=a)
    and exists(select 1 from app_private.profiles where user_id=b),'borra datos propios y compartidos y conserva la cuenta de B');
  update app_private.account_deletions set retry_at=clock_timestamp() where id=(job->>'id')::uuid;
  set local role service_role;
  result := public.claim_account_deletion()->'job';
  perform public.m6_assert(result->>'stage'='auth_pending' and result->>'lease_token'<>job->>'lease_token',
    'reintento continúa en Auth con otra concesión');
  reset role;
  delete from auth.users where id=a;
  set local role service_role;
  perform public.m6_assert(public.finish_account_deletion((result->>'id')::uuid,(result->>'lease_token')::uuid)='{"ok":true}'::jsonb,
    'finaliza tras eliminar la identidad');
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',a::text,true);
  perform public.m6_assert(public.register_profile('Renacer',true)->>'error'='auth',
    'el JWT de una cuenta eliminada no recrea perfil');
  reset role;
  perform public.m6_assert(exists(select 1 from app_private.account_deletions where id=(result->>'id')::uuid
    and user_id is null and stage='complete'),'tarea completada sin identificador personal');

  set local role authenticated;
  perform set_config('request.jwt.claim.sub',b::text,true);
  invite := replace(gen_random_uuid()::text,'-','');
  perform public.create_invitation(invite,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',c::text,true);
  perform public.register_profile('Prueba C',true);
  pair := (public.accept_invitation(invite,gen_random_uuid())->'pair'->>'id')::uuid;
  perform set_config('request.jwt.claim.sub',b::text,true);
  perform public.request_account_deletion();
  perform set_config('request.jwt.claim.sub',c::text,true);
  perform public.m6_assert(public.get_pair_state(pair)->>'error'='pair_unavailable'
    and not(public.get_connection_state() ? 'pair'),'solicitar baja revoca un vínculo activo inmediatamente');
end;
$$;
select 'M6 OK';
rollback;
