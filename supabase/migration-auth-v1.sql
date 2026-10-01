-- Clímax Portal — migração de autenticação V1
-- Execute no SQL Editor DEPOIS do schema.sql já ter sido executado.

create extension if not exists pgcrypto;
create extension if not exists unaccent;

alter table public.profiles
  add column if not exists access_name text,
  add column if not exists access_key text,
  add column if not exists auth_email text,
  add column if not exists recovery_email text;

create unique index if not exists profiles_access_key_unique
  on public.profiles(access_key)
  where access_key is not null;

create unique index if not exists profiles_auth_email_unique
  on public.profiles(lower(auth_email))
  where auth_email is not null;

create table if not exists public.account_security (
  user_id uuid primary key references auth.users(id) on delete cascade,
  activation_code_hash text,
  activation_expires_at timestamptz,
  activation_failed_attempts integer not null default 0,
  activation_locked_until timestamptz,
  activated_at timestamptz,
  recovery_question_key text,
  recovery_answer_hash text,
  recovery_failed_attempts integer not null default 0,
  recovery_locked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.account_security enable row level security;
-- Sem políticas públicas: somente Edge Functions com chave secreta acessam esta tabela.

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

create or replace function public.set_account_security_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_account_security_updated_at on public.account_security;
create trigger set_account_security_updated_at
before update on public.account_security
for each row execute function public.set_account_security_updated_at();

create or replace function public.set_client_commercials_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_client_commercials_updated_at on public.client_commercials;
create trigger set_client_commercials_updated_at
before update on public.client_commercials
for each row execute function public.set_client_commercials_updated_at();

-- Normaliza o nome de acesso para comparação no banco.
create or replace function public.normalize_access_name(value text)
returns text
language sql
immutable
as $$
  select trim(regexp_replace(lower(unaccent(coalesce(value,''))), '[[:space:]]+', ' ', 'g'));
$$;

-- Atualiza automaticamente access_key quando access_name mudar.
create or replace function public.set_profile_access_key()
returns trigger
language plpgsql
as $$
begin
  if new.access_name is not null then
    new.access_key = public.normalize_access_name(new.access_name);
  end if;
  return new;
end;
$$;

drop trigger if exists set_profile_access_key on public.profiles;
create trigger set_profile_access_key
before insert or update of access_name on public.profiles
for each row execute function public.set_profile_access_key();

create index if not exists idx_profiles_access_key on public.profiles(access_key);
create index if not exists idx_account_security_activation on public.account_security(activation_expires_at);

-- Mantém perfil criado automaticamente para novos usuários.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, auth_email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email,''), '@', 1)),
    'client',
    new.email
  )
  on conflict (id) do update set auth_email = excluded.auth_email;
  return new;
end;
$$;

notify pgrst, 'reload schema';
