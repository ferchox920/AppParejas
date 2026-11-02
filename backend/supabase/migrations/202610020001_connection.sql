-- Etapa 2: identidad, consentimiento de prueba e invitación bilateral.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create table app_private.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 30),
  consent_version text not null,
  consent_at timestamptz not null default now()
);
create table app_private.pairs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'active' check (status in ('active', 'ended')),
  created_at timestamptz not null default now()
);
create table app_private.pair_members (
  pair_id uuid not null references app_private.pairs(id),
  user_id uuid not null references auth.users(id),
  active boolean not null default true,
  primary key (pair_id, user_id)
);
create unique index one_active_pair_per_user on app_private.pair_members(user_id) where active;
create table app_private.invitations (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references app_private.profiles(user_id),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '72 hours'),
  status text not null default 'active' check (status in ('active', 'accepted', 'cancelled')),
  accepted_by uuid references auth.users(id),
  pair_id uuid references app_private.pairs(id)
);
create unique index one_pending_invitation_per_user on app_private.invitations(inviter_id) where status = 'active';
create table app_private.receipts (
  user_id uuid not null references auth.users(id),
  operation_id uuid not null,
  operation text not null,
  payload_hash text not null,
  result_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, operation_id)
);
create table app_private.invitation_attempts (
  user_id uuid primary key references auth.users(id),
  window_start timestamptz not null,
  attempts integer not null
);
alter table app_private.profiles enable row level security;
alter table app_private.pairs enable row level security;
alter table app_private.pair_members enable row level security;
alter table app_private.invitations enable row level security;
alter table app_private.receipts enable row level security;
alter table app_private.invitation_attempts enable row level security;
revoke all on all tables in schema app_private from public, anon, authenticated;

create function app_private.error(code text) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('ok', false, 'error', code);
$$;
create function app_private.pair_view(pair uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'status', 'confirmed', 'demo', false, 'continued', false)
  from app_private.pairs p where p.id = pair and p.status = 'active';
$$;
create function app_private.invitation_view(invitation uuid) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object('id', i.id, 'inviter_id', i.inviter_id,
    'inviter_name', p.display_name, 'expires_at', extract(epoch from i.expires_at),
    'status', i.status, 'demo', false, 'pin', '', 'link', '')
  from app_private.invitations i join app_private.profiles p on p.user_id = i.inviter_id
  where i.id = invitation;
$$;
create function app_private.may_attempt(actor uuid) returns boolean
language plpgsql set search_path = '' as $$
declare total integer;
begin
  insert into app_private.invitation_attempts(user_id, window_start, attempts)
    values(actor, clock_timestamp(), 1)
  on conflict(user_id) do update set
    attempts = case when invitation_attempts.window_start < clock_timestamp() - interval '15 minutes'
      then 1 else invitation_attempts.attempts + 1 end,
    window_start = case when invitation_attempts.window_start < clock_timestamp() - interval '15 minutes'
      then clock_timestamp() else invitation_attempts.window_start end
  returning attempts into total;
  return total <= 15;
end;
$$;

create function public.register_profile(p_name text, p_consent boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); clean text := btrim(p_name);
begin
  if actor is null then return app_private.error('auth'); end if;
  if p_consent is distinct from true then return app_private.error('consent'); end if;
  if clean is null or char_length(clean) not between 2 and 30 or clean ~ '[[:cntrl:]]'
    then return app_private.error('name'); end if;
  insert into app_private.profiles(user_id, display_name, consent_version)
    values(actor, clean, 'development-1')
  on conflict(user_id) do update set display_name = excluded.display_name;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.get_connection_state() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); pair uuid; invitation uuid;
begin
  if actor is null or not exists(select 1 from app_private.profiles where user_id = actor)
    then return app_private.error('auth'); end if;
  select m.pair_id into pair from app_private.pair_members m
    join app_private.pairs p on p.id = m.pair_id where m.user_id = actor and m.active and p.status = 'active';
  if pair is not null then
    return jsonb_build_object('ok', true, 'pair', app_private.pair_view(pair));
  end if;
  select id into invitation from app_private.invitations
    where inviter_id = actor and status = 'active' and expires_at > now();
  if invitation is not null then
    return jsonb_build_object('ok', true, 'invitation', app_private.invitation_view(invitation));
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.create_invitation(p_token text, p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); token_digest text; invitation uuid; item app_private.receipts;
begin
  if actor is null or not exists(select 1 from app_private.profiles where user_id = actor)
    then return app_private.error('auth'); end if;
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' or p_operation_id is null
    then return app_private.error('invalid_pin'); end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  token_digest := encode(extensions.digest(p_token, 'sha256'), 'hex');
  select * into item from app_private.receipts where user_id = actor and operation_id = p_operation_id;
  if found then
    if item.operation != 'create' or item.payload_hash != token_digest
      then return app_private.error('operation_conflict'); end if;
    select id into invitation from app_private.invitations where id = item.result_id
      and inviter_id = actor and status = 'active' and expires_at > now();
    if invitation is null then return app_private.error('unavailable'); end if;
  else
    if exists(select 1 from app_private.pair_members where user_id = actor and active)
      then return app_private.error('already_linked'); end if;
    update app_private.invitations set status = 'cancelled'
      where inviter_id = actor and status = 'active' and expires_at <= now();
    if exists(select 1 from app_private.invitations where inviter_id = actor and status = 'active')
      then return app_private.error('pending_invitation'); end if;
    insert into app_private.invitations(inviter_id, token_hash) values(actor, token_digest) returning id into invitation;
    insert into app_private.receipts(user_id, operation_id, operation, payload_hash, result_id)
      values(actor, p_operation_id, 'create', token_digest, invitation);
  end if;
  return jsonb_build_object('ok', true, 'invitation', app_private.invitation_view(invitation)
    || jsonb_build_object('pin', p_token, 'link', p_token));
end;
$$;

create function public.resolve_invitation(p_token text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); invitation uuid; inviter uuid;
begin
  if actor is null or not exists(select 1 from app_private.profiles where user_id = actor)
    then return app_private.error('auth'); end if;
  if not app_private.may_attempt(actor) then return app_private.error('rate_limited'); end if;
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then return app_private.error('invalid_pin'); end if;
  select id, inviter_id into invitation, inviter from app_private.invitations
    where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex') and status = 'active' and expires_at > now();
  if invitation is null then return app_private.error('invalid_pin'); end if;
  if inviter = actor then return app_private.error('self_invitation'); end if;
  if exists(select 1 from app_private.pair_members where user_id in (actor, inviter) and active)
    then return app_private.error('already_linked'); end if;
  return jsonb_build_object('ok', true, 'invitation', app_private.invitation_view(invitation));
end;
$$;

create function public.accept_invitation(p_token text, p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); inviter uuid; item app_private.invitations;
  receipt app_private.receipts; pair uuid; token_digest text; lock_user uuid;
begin
  if actor is null or not exists(select 1 from app_private.profiles where user_id = actor)
    then return app_private.error('auth'); end if;
  if not app_private.may_attempt(actor) then return app_private.error('rate_limited'); end if;
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' or p_operation_id is null
    then return app_private.error('invalid_pin'); end if;
  token_digest := encode(extensions.digest(p_token, 'sha256'), 'hex');
  select inviter_id into inviter from app_private.invitations where token_hash = token_digest;
  if inviter is null then return app_private.error('invalid_pin'); end if;
  if inviter = actor then return app_private.error('self_invitation'); end if;
  -- Orden común con creación y cancelación; evita dobles vínculos y bloqueos circulares.
  for lock_user in select x from unnest(array[actor, inviter]) x order by x loop
    perform pg_advisory_xact_lock(hashtextextended(lock_user::text, 0));
  end loop;
  select * into item from app_private.invitations where token_hash = token_digest for update;
  select * into receipt from app_private.receipts where user_id = actor and operation_id = p_operation_id;
  if found and (receipt.operation != 'accept' or receipt.payload_hash != token_digest)
    then return app_private.error('operation_conflict'); end if;
  if item.status = 'accepted' and item.accepted_by = actor
    and exists(select 1 from app_private.pair_members m join app_private.pairs p on p.id = m.pair_id
      where m.user_id = actor and m.pair_id = item.pair_id and m.active and p.status = 'active') then
    return jsonb_build_object('ok', true, 'pair', app_private.pair_view(item.pair_id));
  end if;
  if item.status != 'active' or item.expires_at <= now() then return app_private.error('invalid_pin'); end if;
  if exists(select 1 from app_private.pair_members where user_id in (actor, inviter) and active)
    then return app_private.error('already_linked'); end if;
  insert into app_private.pairs default values returning id into pair;
  insert into app_private.pair_members(pair_id, user_id) values(pair, actor), (pair, inviter);
  update app_private.invitations set status = 'accepted', accepted_by = actor, pair_id = pair where id = item.id;
  update app_private.invitations set status = 'cancelled' where inviter_id in (actor, inviter) and status = 'active';
  insert into app_private.receipts(user_id, operation_id, operation, payload_hash, result_id)
    values(actor, p_operation_id, 'accept', token_digest, pair);
  return jsonb_build_object('ok', true, 'pair', app_private.pair_view(pair));
end;
$$;

create function public.cancel_invitation(p_invitation_id uuid, p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); item app_private.invitations; receipt app_private.receipts;
begin
  if actor is null then return app_private.error('auth'); end if;
  if p_invitation_id is null or p_operation_id is null then return app_private.error('unavailable'); end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  select * into item from app_private.invitations where id = p_invitation_id and inviter_id = actor for update;
  if not found then return app_private.error('unavailable'); end if;
  select * into receipt from app_private.receipts where user_id = actor and operation_id = p_operation_id;
  if found then
    if receipt.operation != 'cancel' or receipt.payload_hash != p_invitation_id::text
      then return app_private.error('operation_conflict'); end if;
    return jsonb_build_object('ok', true);
  end if;
  if item.status = 'accepted' then return app_private.error('used'); end if;
  update app_private.invitations set status = 'cancelled' where id = item.id;
  insert into app_private.receipts(user_id, operation_id, operation, payload_hash, result_id)
    values(actor, p_operation_id, 'cancel', p_invitation_id::text, item.id);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on all functions in schema app_private from public, anon, authenticated;
revoke all on function public.register_profile(text, boolean), public.get_connection_state(),
  public.create_invitation(text, uuid), public.resolve_invitation(text), public.accept_invitation(text, uuid),
  public.cancel_invitation(uuid, uuid) from public, anon;
grant execute on function public.register_profile(text, boolean), public.get_connection_state(),
  public.create_invitation(text, uuid), public.resolve_invitation(text), public.accept_invitation(text, uuid),
  public.cancel_invitation(uuid, uuid) to authenticated;
