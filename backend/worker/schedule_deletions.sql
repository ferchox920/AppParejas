-- Ejecutar en AppParejas-desarrollo después de guardar la clave existente en Vault.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.schedule(
 'appparejas-account-deletion', '* * * * *',
 $job$
 select net.http_post(
   url := 'https://divtaatbojwxiahshhir.supabase.co/functions/v1/account-deletion-worker',
   headers := jsonb_build_object(
     'Content-Type','application/json',
     'Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets
       where name='appparejas_deletion_worker_service')),
   body := '{}'::jsonb,
   timeout_milliseconds := 60000
 );
 $job$
);
select cron.schedule('appparejas-retention','17 3 * * *','select public.purge_expired_app_data();');
select jobname,schedule,active from cron.job
where jobname in ('appparejas-account-deletion','appparejas-retention')
order by jobname;
