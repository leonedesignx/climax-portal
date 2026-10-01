-- Clímax Portal — FINAL-HARDENING.sql
-- Execute UMA VEZ (ou reaplique com segurança) no SQL Editor do projeto atual.
-- Idempotente: usa IF NOT EXISTS / CREATE OR REPLACE / DROP POLICY IF EXISTS.

create extension if not exists pgcrypto;
create extension if not exists unaccent;

-- -----------------------------------------------------------------------------
-- Perfis e primeiro acesso
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists access_name text,
  add column if not exists access_key text,
  add column if not exists auth_email text,
  add column if not exists recovery_email text,
  add column if not exists must_change_password boolean not null default true;

create or replace function public.normalize_access_name(value text)
returns text
language sql
immutable
as $$
  select trim(regexp_replace(lower(unaccent(coalesce(value,''))), '[[:space:]]+', ' ', 'g'));
$$;

create unique index if not exists profiles_access_key_unique
  on public.profiles(access_key)
  where access_key is not null;

create unique index if not exists profiles_auth_email_unique
  on public.profiles(lower(auth_email))
  where auth_email is not null;

create or replace function public.set_profile_access_key()
returns trigger
language plpgsql
as $$
begin
  if new.access_name is not null then
    new.access_key := public.normalize_access_name(new.access_name);
  else
    new.access_key := null;
  end if;
  return new;
end;
$$;

drop trigger if exists set_profile_access_key on public.profiles;
create trigger set_profile_access_key
before insert or update of access_name on public.profiles
for each row execute function public.set_profile_access_key();

-- Recalcula chaves já existentes, caso alguma conta tenha sido criada antes do trigger.
update public.profiles
set access_key = public.normalize_access_name(access_name)
where access_name is not null
  and access_key is distinct from public.normalize_access_name(access_name);

create or replace function public.complete_first_access()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão inválida.';
  end if;

  update public.profiles
  set must_change_password = false,
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'Perfil não encontrado.';
  end if;
end;
$$;

revoke all on function public.complete_first_access() from public;
revoke all on function public.complete_first_access() from anon;
grant execute on function public.complete_first_access() to authenticated;

-- -----------------------------------------------------------------------------
-- Dados comerciais privados do Admin
-- -----------------------------------------------------------------------------
create table if not exists public.client_commercials (
  client_id uuid primary key references public.clients(id) on delete cascade,
  services text[] not null default '{}',
  monthly_fee numeric(12,2),
  deliverables_per_month integer,
  contract_status text not null default 'none' check (contract_status in ('none','active','ended','informal')),
  pricing_plan jsonb not null default '{}'::jsonb,
  internal_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.client_commercials enable row level security;

drop policy if exists "client_commercials_admin_read" on public.client_commercials;
create policy "client_commercials_admin_read" on public.client_commercials
for select using (public.is_admin());

drop policy if exists "client_commercials_admin_write" on public.client_commercials;
create policy "client_commercials_admin_write" on public.client_commercials
for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.set_client_commercials_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_client_commercials_updated_at on public.client_commercials;
create trigger set_client_commercials_updated_at
before update on public.client_commercials
for each row execute function public.set_client_commercials_updated_at();

-- -----------------------------------------------------------------------------
-- Vincular um usuário Auth já criado a um cliente.
-- IMPORTANTE: esta RPC NÃO cria usuário no Auth e não usa service_role no browser.
-- O usuário técnico deve ser criado antes em Authentication -> Users.
-- -----------------------------------------------------------------------------
create or replace function public.link_existing_client_user(
  p_name text,
  p_access_name text,
  p_auth_email text,
  p_contact_name text default '',
  p_contact_email text default null,
  p_category text default 'Social Media',
  p_monthly_fee numeric default null,
  p_deliverables integer default null,
  p_contract_status text default 'none',
  p_internal_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_client_id uuid;
  v_initials text;
  v_existing_role text;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Somente administradores podem vincular clientes.';
  end if;

  p_name := trim(coalesce(p_name,''));
  p_access_name := trim(coalesce(p_access_name,''));
  p_auth_email := lower(trim(coalesce(p_auth_email,'')));
  p_contact_name := trim(coalesce(p_contact_name,''));
  p_contact_email := nullif(trim(coalesce(p_contact_email,'')), '');
  p_category := trim(coalesce(nullif(p_category,''),'Social Media'));
  p_internal_notes := nullif(trim(coalesce(p_internal_notes,'')), '');

  if p_name = '' then raise exception 'Informe o nome do cliente.'; end if;
  if p_access_name = '' then raise exception 'Informe o nome de acesso.'; end if;
  if p_auth_email = '' then raise exception 'E-mail técnico inválido.'; end if;
  if p_contract_status not in ('none','active','ended','informal') then
    raise exception 'Status de contrato inválido.';
  end if;
  if p_monthly_fee is not null and p_monthly_fee < 0 then
    raise exception 'Valor mensal inválido.';
  end if;
  if p_deliverables is not null and p_deliverables < 0 then
    raise exception 'Quantidade de entregas inválida.';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = p_auth_email
  limit 1;

  if v_user_id is null then
    raise exception 'Usuário técnico não encontrado no Authentication: %', p_auth_email;
  end if;

  if v_user_id = auth.uid() then
    raise exception 'Não é permitido transformar a própria conta administrativa em cliente.';
  end if;

  select p.role, p.client_id
    into v_existing_role, v_client_id
  from public.profiles p
  where p.id = v_user_id;

  if v_existing_role = 'admin' then
    raise exception 'Este usuário já possui perfil administrativo.';
  end if;

  v_initials := upper(
    left(p_name,1) ||
    case
      when p_name ~ '[[:space:]]' then left(regexp_replace(p_name, '^.*[[:space:]]+', ''),1)
      else ''
    end
  );

  if v_client_id is null then
    insert into public.clients(name, initials, contact_name, contact_email, category, active, created_by)
    values(p_name, nullif(v_initials,''), nullif(p_contact_name,''), p_contact_email, p_category, true, auth.uid())
    returning id into v_client_id;
  else
    update public.clients
    set name = p_name,
        initials = coalesce(nullif(v_initials,''), initials),
        contact_name = nullif(p_contact_name,''),
        contact_email = p_contact_email,
        category = p_category,
        active = true,
        updated_at = now()
    where id = v_client_id;
  end if;

  insert into public.profiles(id, full_name, role, client_id, access_name, access_key, auth_email, must_change_password)
  values(
    v_user_id,
    p_name,
    'client',
    v_client_id,
    p_access_name,
    public.normalize_access_name(p_access_name),
    p_auth_email,
    true
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    role = 'client',
    client_id = excluded.client_id,
    access_name = excluded.access_name,
    access_key = excluded.access_key,
    auth_email = excluded.auth_email,
    must_change_password = true,
    updated_at = now();

  insert into public.client_commercials(
    client_id, services, monthly_fee, deliverables_per_month, contract_status, internal_notes
  ) values (
    v_client_id,
    array[p_category],
    p_monthly_fee,
    p_deliverables,
    p_contract_status,
    p_internal_notes
  )
  on conflict (client_id) do update set
    services = excluded.services,
    monthly_fee = excluded.monthly_fee,
    deliverables_per_month = excluded.deliverables_per_month,
    contract_status = excluded.contract_status,
    internal_notes = excluded.internal_notes,
    updated_at = now();

  return jsonb_build_object(
    'client_id', v_client_id,
    'user_id', v_user_id,
    'access_name', p_access_name,
    'auth_email', p_auth_email
  );
end;
$$;

revoke all on function public.link_existing_client_user(text,text,text,text,text,text,numeric,integer,text,text) from public;
revoke all on function public.link_existing_client_user(text,text,text,text,text,text,numeric,integer,text,text) from anon;
grant execute on function public.link_existing_client_user(text,text,text,text,text,text,numeric,integer,text,text) to authenticated;

notify pgrst, 'reload schema';
