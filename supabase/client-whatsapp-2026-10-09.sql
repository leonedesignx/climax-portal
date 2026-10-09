-- Clímax Portal — WhatsApp manual por cliente
-- Aplicado no Supabase de produção em 2026-10-09.
alter table public.clients
  add column if not exists whatsapp_phone text;
