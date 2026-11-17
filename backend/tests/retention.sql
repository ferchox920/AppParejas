\set ON_ERROR_STOP on
begin;
do $$
declare
  old_pair uuid := gen_random_uuid();
  recent_pair uuid := gen_random_uuid();
  active_pair uuid := gen_random_uuid();
  actor uuid := gen_random_uuid();
  result jsonb;
begin
  insert into auth.users values(actor);
  insert into app_private.pairs(id,status,ended_at) values
    (old_pair,'ended',now()-interval '31 days'),
    (recent_pair,'ended',now()-interval '29 days'),
    (active_pair,'active',null);
  insert into app_private.pair_members values (old_pair,actor,false);
  insert into app_private.receipts(user_id,operation_id,operation,payload_hash,result_id,created_at) values
    (actor,gen_random_uuid(),'test','old',old_pair,now()-interval '31 days'),
    (actor,gen_random_uuid(),'test','recent',recent_pair,now()-interval '29 days');
  insert into app_private.account_deletions(stage,completed_at) values
    ('complete',now()-interval '31 days'),('complete',now()-interval '29 days');
  set local role service_role;
  result := public.purge_expired_app_data();
  reset role;
  if result->>'ok'<>'true'
    or exists(select 1 from app_private.pairs where id=old_pair)
    or (select count(*) from app_private.pairs where id in(recent_pair,active_pair))<>2
    or exists(select 1 from app_private.receipts where user_id=actor and payload_hash='old')
    or not exists(select 1 from app_private.receipts where user_id=actor and payload_hash='recent')
    or exists(select 1 from app_private.account_deletions where completed_at<now()-interval '30 days') then
    raise exception 'Retención falló';
  end if;
end;
$$;
select 'RETENCIÓN OK';
rollback;
