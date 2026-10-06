-- Clímax Portal — Drive em conteúdos
-- Aplicado no Supabase de produção em 2026-10-06.
alter table public.contents
  add column if not exists drive_url text;
