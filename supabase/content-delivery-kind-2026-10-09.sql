-- Clímax Portal — tipo real de entrega dos conteúdos
-- Aplicado no Supabase de produção em 2026-10-09.
alter table public.contents
  add column if not exists delivery_kind text;

update public.contents
set delivery_kind = case
  when lower(type) = 'reels' then 'video'
  when lower(type) = 'carrossel' then 'carousel'
  when lower(type) in ('post','story') then 'image'
  else 'other'
end
where delivery_kind is null;

alter table public.contents
  alter column delivery_kind set default 'image';

alter table public.contents
  drop constraint if exists contents_delivery_kind_check;

alter table public.contents
  add constraint contents_delivery_kind_check
  check (delivery_kind in ('video','image','carousel','site','document','other'));
