-- Fluxo de publicação do Clímax Portal
-- Execute após FINAL-HARDENING.sql, no SQL Editor do Supabase.
-- A alteração é idempotente e mantém a segurança RLS existente.

alter table public.contents
  add column if not exists planned_publish_date date,
  add column if not exists publication_status text not null default 'not_ready',
  add column if not exists published_at timestamptz;

alter table public.contents drop constraint if exists contents_publication_status_check;
alter table public.contents
  add constraint contents_publication_status_check
  check (publication_status in ('not_ready','ready','scheduled','published'));

update public.contents
set planned_publish_date = coalesce(planned_publish_date, (scheduled_at at time zone 'America/Sao_Paulo')::date),
    publication_status = case
      when status = 'approved' and scheduled_at is not null then 'scheduled'
      when status = 'approved' then 'ready'
      else 'not_ready'
    end
where publication_status = 'not_ready';

create unique index if not exists contents_editorial_item_unique
  on public.contents (editorial_item_id)
  where editorial_item_id is not null;

create index if not exists contents_publication_status_scheduled_at_idx
  on public.contents (publication_status, scheduled_at);

create or replace function public.sync_content_publication_status()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'approved' and old.status is distinct from 'approved' then
    new.publication_status := 'ready';
    new.published_at := null;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_content_publication_status() from public, anon, authenticated;

drop trigger if exists sync_content_publication_status on public.contents;
create trigger sync_content_publication_status
before update of status on public.contents
for each row execute function public.sync_content_publication_status();

create or replace function public.materialize_approved_editorial()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.contents (
    client_id, editorial_item_id, title, type, delivery_kind, caption,
    planned_publish_date, publication_status, status, current_version, created_by
  )
  select
    e.client_id,
    i.id,
    i.title,
    i.format,
    case
      when lower(i.format) = 'reels' then 'video'
      when lower(i.format) = 'carrossel' then 'carousel'
      when lower(i.format) in ('post','story') then 'image'
      else 'other'
    end,
    coalesce(i.caption_draft, i.idea, ''),
    i.publish_date,
    'not_ready',
    'draft',
    1,
    new.approved_by
  from public.editorial_items i
  join public.editorials e on e.id = new.editorial_id
  where i.editorial_version_id = new.id
  on conflict (editorial_item_id) where editorial_item_id is not null do nothing;
  return new;
end;
$$;

revoke all on function public.materialize_approved_editorial() from public, anon, authenticated;
drop trigger if exists materialize_approved_editorial on public.editorial_versions;
create trigger materialize_approved_editorial
after update of status on public.editorial_versions
for each row
when (new.status = 'approved' and old.status is distinct from 'approved')
execute function public.materialize_approved_editorial();

-- Materialize editorials that were already approved before this migration ran.
insert into public.contents (
  client_id, editorial_item_id, title, type, delivery_kind, caption,
  planned_publish_date, publication_status, status, current_version, created_by
)
select
  e.client_id,
  i.id,
  i.title,
  i.format,
  case
    when lower(i.format) = 'reels' then 'video'
    when lower(i.format) = 'carrossel' then 'carousel'
    when lower(i.format) in ('post','story') then 'image'
    else 'other'
  end,
  coalesce(i.caption_draft, i.idea, ''),
  i.publish_date,
  'not_ready',
  'draft',
  1,
  v.approved_by
from public.editorial_versions v
join public.editorials e on e.id = v.editorial_id
join public.editorial_items i on i.editorial_version_id = v.id
where v.status = 'approved'
on conflict (editorial_item_id) where editorial_item_id is not null do nothing;

-- The trigger is the only intended entrypoint for the definer function.
