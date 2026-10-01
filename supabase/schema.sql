-- Clímax Portal — schema inicial de produção
-- Execute este arquivo no SQL Editor de um projeto Supabase vazio.

create extension if not exists pgcrypto;

-- ---------- tabelas base ----------
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  initials text,
  contact_name text,
  contact_email text,
  category text not null default 'Social Media',
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'client' check (role in ('admin','client')),
  client_id uuid references public.clients(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.editorials (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  month_start date not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(client_id, month_start)
);

create table if not exists public.editorial_versions (
  id uuid primary key default gen_random_uuid(),
  editorial_id uuid not null references public.editorials(id) on delete cascade,
  version integer not null default 1 check (version > 0),
  status text not null default 'draft' check (status in ('draft','waiting','changes','approved')),
  feedback text,
  sent_at timestamptz,
  approved_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(editorial_id, version)
);

create table if not exists public.editorial_items (
  id uuid primary key default gen_random_uuid(),
  editorial_version_id uuid not null references public.editorial_versions(id) on delete cascade,
  publish_date date,
  format text not null check (format in ('Post','Carrossel','Reels','Story')),
  title text not null,
  idea text,
  objective text,
  reference_url text,
  reference_label text,
  production_notes text,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.contents (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  editorial_item_id uuid references public.editorial_items(id) on delete set null,
  title text not null,
  type text not null check (type in ('Post','Carrossel','Reels','Story')),
  caption text,
  scheduled_at timestamptz,
  status text not null default 'draft' check (status in ('draft','material','waiting','changes','approved')),
  current_version integer not null default 1 check (current_version > 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.content_versions (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  version integer not null check (version > 0),
  media_key text,
  thumbnail_key text,
  media_type text,
  size_bytes bigint,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(content_id, version)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid references public.contents(id) on delete cascade,
  editorial_version_id uuid references public.editorial_versions(id) on delete cascade,
  editorial_item_id uuid references public.editorial_items(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  check (
    (content_id is not null)::int +
    (editorial_version_id is not null)::int +
    (editorial_item_id is not null)::int = 1
  )
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid references public.contents(id) on delete cascade,
  editorial_version_id uuid references public.editorial_versions(id) on delete cascade,
  action text not null check (action in ('approved','changes')),
  note text,
  version integer,
  created_at timestamptz not null default now(),
  check (
    (content_id is not null)::int +
    (editorial_version_id is not null)::int = 1
  )
);

-- ---------- utilidades ----------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_clients_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger set_editorial_items_updated_at
before update on public.editorial_items
for each row execute function public.set_updated_at();

create trigger set_contents_updated_at
before update on public.contents
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email,''), '@', 1)),
    'client'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select client_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_role() = 'admin', false);
$$;

-- ---------- RLS ----------
alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.editorials enable row level security;
alter table public.editorial_versions enable row level security;
alter table public.editorial_items enable row level security;
alter table public.contents enable row level security;
alter table public.content_versions enable row level security;
alter table public.comments enable row level security;
alter table public.reviews enable row level security;

-- Profiles
create policy "profiles_read_self_or_admin" on public.profiles
for select using (id = auth.uid() or public.is_admin());
create policy "profiles_admin_update" on public.profiles
for update using (public.is_admin()) with check (public.is_admin());

-- Clients
create policy "clients_read_scope" on public.clients
for select using (public.is_admin() or id = public.current_client_id());
create policy "clients_admin_insert" on public.clients
for insert with check (public.is_admin());
create policy "clients_admin_update" on public.clients
for update using (public.is_admin()) with check (public.is_admin());
create policy "clients_admin_delete" on public.clients
for delete using (public.is_admin());

-- Editorials
create policy "editorials_read_scope" on public.editorials
for select using (public.is_admin() or client_id = public.current_client_id());
create policy "editorials_admin_write" on public.editorials
for all using (public.is_admin()) with check (public.is_admin());

-- Editorial versions
create policy "editorial_versions_read_scope" on public.editorial_versions
for select using (
  public.is_admin() or exists (
    select 1 from public.editorials e
    where e.id = editorial_id and e.client_id = public.current_client_id()
  )
);
create policy "editorial_versions_admin_write" on public.editorial_versions
for all using (public.is_admin()) with check (public.is_admin());

-- Editorial items
create policy "editorial_items_read_scope" on public.editorial_items
for select using (
  public.is_admin() or exists (
    select 1
    from public.editorial_versions ev
    join public.editorials e on e.id = ev.editorial_id
    where ev.id = editorial_version_id
      and e.client_id = public.current_client_id()
  )
);
create policy "editorial_items_admin_write" on public.editorial_items
for all using (public.is_admin()) with check (public.is_admin());

-- Contents
create policy "contents_read_scope" on public.contents
for select using (public.is_admin() or client_id = public.current_client_id());
create policy "contents_admin_write" on public.contents
for all using (public.is_admin()) with check (public.is_admin());

-- Content versions
create policy "content_versions_read_scope" on public.content_versions
for select using (
  public.is_admin() or exists (
    select 1 from public.contents c
    where c.id = content_id and c.client_id = public.current_client_id()
  )
);
create policy "content_versions_admin_write" on public.content_versions
for all using (public.is_admin()) with check (public.is_admin());

-- Comments
create policy "comments_read_scope" on public.comments
for select using (public.is_admin() or client_id = public.current_client_id());
create policy "comments_insert_scope" on public.comments
for insert with check (
  author_id = auth.uid()
  and (public.is_admin() or client_id = public.current_client_id())
);

-- Reviews are immutable audit records
create policy "reviews_read_scope" on public.reviews
for select using (public.is_admin() or client_id = public.current_client_id());

-- ---------- RPCs para aprovações ----------
create or replace function public.review_content(
  p_content_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_content public.contents%rowtype;
begin
  if p_action not in ('approved','changes') then
    raise exception 'Ação inválida';
  end if;

  select * into v_content from public.contents where id = p_content_id;
  if not found then raise exception 'Conteúdo não encontrado'; end if;

  if not public.is_admin() and v_content.client_id <> public.current_client_id() then
    raise exception 'Acesso negado';
  end if;

  update public.contents
  set status = case when p_action='approved' then 'approved' else 'changes' end,
      updated_at = now()
  where id = p_content_id;

  insert into public.reviews(client_id, actor_id, content_id, action, note, version)
  values(v_content.client_id, auth.uid(), p_content_id, p_action, nullif(trim(p_note),''), v_content.current_version);

  if p_note is not null and trim(p_note) <> '' then
    insert into public.comments(client_id, author_id, content_id, body)
    values(v_content.client_id, auth.uid(), p_content_id, trim(p_note));
  end if;
end;
$$;

grant execute on function public.review_content(uuid,text,text) to authenticated;

create or replace function public.review_editorial(
  p_editorial_version_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version public.editorial_versions%rowtype;
  v_client uuid;
begin
  if p_action not in ('approved','changes') then
    raise exception 'Ação inválida';
  end if;

  select ev.* into v_version
  from public.editorial_versions ev
  where ev.id = p_editorial_version_id;
  if not found then raise exception 'Editorial não encontrado'; end if;

  select e.client_id into v_client from public.editorials e where e.id = v_version.editorial_id;

  if not public.is_admin() and v_client <> public.current_client_id() then
    raise exception 'Acesso negado';
  end if;

  update public.editorial_versions
  set status = case when p_action='approved' then 'approved' else 'changes' end,
      feedback = nullif(trim(p_note),''),
      approved_at = case when p_action='approved' then now() else null end,
      approved_by = case when p_action='approved' then auth.uid() else null end
  where id = p_editorial_version_id;

  insert into public.reviews(client_id, actor_id, editorial_version_id, action, note, version)
  values(v_client, auth.uid(), p_editorial_version_id, p_action, nullif(trim(p_note),''), v_version.version);
end;
$$;

grant execute on function public.review_editorial(uuid,text,text) to authenticated;

create or replace function public.send_editorial(p_editorial_version_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Acesso negado'; end if;
  update public.editorial_versions
  set status='waiting', sent_at=now(), feedback=null, approved_at=null, approved_by=null
  where id=p_editorial_version_id;
end;
$$;

grant execute on function public.send_editorial(uuid) to authenticated;

-- ---------- índices ----------
create index if not exists idx_profiles_client on public.profiles(client_id);
create index if not exists idx_editorials_client_month on public.editorials(client_id, month_start);
create index if not exists idx_editorial_versions_editorial on public.editorial_versions(editorial_id, version desc);
create index if not exists idx_editorial_items_version on public.editorial_items(editorial_version_id, position);
create index if not exists idx_contents_client on public.contents(client_id);
create index if not exists idx_contents_status on public.contents(status);
create index if not exists idx_contents_schedule on public.contents(scheduled_at);
create index if not exists idx_comments_client on public.comments(client_id, created_at desc);
create index if not exists idx_reviews_client on public.reviews(client_id, created_at desc);

-- ==========================================================
-- AUTENTICAÇÃO V1: nome de acesso, primeiro acesso e recuperação
-- ==========================================================
create extension if not exists unaccent;

alter table public.profiles
  add column if not exists access_name text,
  add column if not exists access_key text,
  add column if not exists auth_email text,
  add column if not exists recovery_email text;

create unique index if not exists profiles_access_key_unique on public.profiles(access_key) where access_key is not null;
create unique index if not exists profiles_auth_email_unique on public.profiles(lower(auth_email)) where auth_email is not null;

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
create policy "client_commercials_admin_read" on public.client_commercials for select using (public.is_admin());
create policy "client_commercials_admin_write" on public.client_commercials for all using (public.is_admin()) with check (public.is_admin());

create or replace function public.normalize_access_name(value text)
returns text language sql immutable as $$
  select trim(regexp_replace(lower(unaccent(coalesce(value,''))), '[[:space:]]+', ' ', 'g'));
$$;

create or replace function public.set_profile_access_key()
returns trigger language plpgsql as $$
begin
  if new.access_name is not null then new.access_key = public.normalize_access_name(new.access_name); end if;
  return new;
end;
$$;
drop trigger if exists set_profile_access_key on public.profiles;
create trigger set_profile_access_key before insert or update of access_name on public.profiles
for each row execute function public.set_profile_access_key();

create or replace function public.set_account_security_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists set_account_security_updated_at on public.account_security;
create trigger set_account_security_updated_at before update on public.account_security
for each row execute function public.set_account_security_updated_at();

create or replace function public.set_client_commercials_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists set_client_commercials_updated_at on public.client_commercials;
create trigger set_client_commercials_updated_at before update on public.client_commercials
for each row execute function public.set_client_commercials_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name,role,auth_email)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(coalesce(new.email,''),'@',1)),'client',new.email)
  on conflict(id) do update set auth_email=excluded.auth_email;
  return new;
end;
$$;

create index if not exists idx_profiles_access_key on public.profiles(access_key);
create index if not exists idx_account_security_activation on public.account_security(activation_expires_at);
notify pgrst, 'reload schema';
