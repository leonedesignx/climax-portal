-- Clímax Portal — imagens demonstrativas / carrossel de aprovação
-- Aplicado no Supabase de produção em 2026-10-09.
create table if not exists public.content_preview_assets (
  id uuid primary key default gen_random_uuid(),
  content_id uuid not null references public.contents(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  storage_key text not null unique,
  file_name text,
  mime_type text,
  size_bytes bigint,
  position integer not null default 0,
  is_cover boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint content_preview_assets_position_check check (position >= 0)
);
alter table public.content_preview_assets enable row level security;
grant select, insert, update, delete on public.content_preview_assets to authenticated;
grant select, insert, update, delete on public.content_preview_assets to service_role;

drop policy if exists "content_preview_assets_read_scope" on public.content_preview_assets;
create policy "content_preview_assets_read_scope" on public.content_preview_assets
for select to authenticated
using ((select is_admin()) or client_id = (select current_client_id()));

drop policy if exists "content_preview_assets_admin_insert" on public.content_preview_assets;
create policy "content_preview_assets_admin_insert" on public.content_preview_assets
for insert to authenticated with check ((select is_admin()));

drop policy if exists "content_preview_assets_admin_update" on public.content_preview_assets;
create policy "content_preview_assets_admin_update" on public.content_preview_assets
for update to authenticated using ((select is_admin())) with check ((select is_admin()));

drop policy if exists "content_preview_assets_admin_delete" on public.content_preview_assets;
create policy "content_preview_assets_admin_delete" on public.content_preview_assets
for delete to authenticated using ((select is_admin()));

create index if not exists content_preview_assets_content_idx on public.content_preview_assets(content_id, position);
create index if not exists content_preview_assets_client_idx on public.content_preview_assets(client_id);
