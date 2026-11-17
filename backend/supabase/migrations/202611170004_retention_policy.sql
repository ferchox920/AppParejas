-- Política del piloto acordada con el titular: treinta días.
create function public.purge_expired_app_data() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  expired_pairs uuid[];
  threshold timestamptz := clock_timestamp() - interval '30 days';
  receipt_count integer;
  task_count integer;
begin
  select array_agg(p.id) into expired_pairs from (
    select id from app_private.pairs
    where status = 'ended' and ended_at < threshold
    order by id for update skip locked
  ) p;
  delete from app_private.milestone_views where milestone_id in (
    select m.id from app_private.cultivation_milestones m
    join app_private.cultivations c on c.id = m.cultivation_id where c.pair_id = any(expired_pairs));
  delete from app_private.cultivation_milestones where cultivation_id in (
    select id from app_private.cultivations where pair_id = any(expired_pairs));
  delete from app_private.cultivations where pair_id = any(expired_pairs);
  delete from app_private.approvals where pair_id = any(expired_pairs);
  delete from app_private.agreements where pair_id = any(expired_pairs);
  delete from app_private.selections where pair_id = any(expired_pairs);
  delete from app_private.invitations where pair_id = any(expired_pairs)
    or (status <> 'active' and created_at < threshold);
  delete from app_private.pair_members where pair_id = any(expired_pairs);
  delete from app_private.pairs where id = any(expired_pairs);
  delete from app_private.receipts where created_at < threshold;
  get diagnostics receipt_count = row_count;
  delete from app_private.account_deletions where stage = 'complete' and completed_at < threshold;
  get diagnostics task_count = row_count;
  return jsonb_build_object('ok',true,'archived_pairs',coalesce(cardinality(expired_pairs),0),
    'receipts',receipt_count,'completed_tasks',task_count);
end;
$$;
revoke all on function public.purge_expired_app_data() from public, anon, authenticated;
grant execute on function public.purge_expired_app_data() to service_role;
