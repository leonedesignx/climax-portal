-- Clímax Portal — Financeiro + editorial colaborativo
-- Aplicado no projeto Supabase climax-portal em 2026-10-06.

alter table public.clients
  add column if not exists display_subtitle text;

alter table public.editorial_items
  add column if not exists caption_draft text,
  add column if not exists drive_url text;

create table if not exists public.client_financials (
  client_id uuid primary key references public.clients(id) on delete cascade,
  monthly_fee numeric(12,2) check (monthly_fee is null or monthly_fee >= 0),
  payment_due_day smallint check (payment_due_day is null or payment_due_day between 1 and 31),
  payment_status text not null default 'not_set'
    check (payment_status in ('not_set','pending','paid','overdue')),
  payment_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.client_financials enable row level security;

drop policy if exists client_financials_admin_read on public.client_financials;
drop policy if exists client_financials_admin_write on public.client_financials;
drop policy if exists client_financials_client_read on public.client_financials;

create policy client_financials_admin_read
on public.client_financials for select
to authenticated
using (public.is_admin());

create policy client_financials_admin_write
on public.client_financials for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy client_financials_client_read
on public.client_financials for select
to authenticated
using (client_id = public.current_client_id());

revoke all on table public.client_financials from anon;
grant select, insert, update, delete on table public.client_financials to authenticated;

create table if not exists public.portal_payment_settings (
  id smallint primary key default 1 check (id = 1),
  pix_key text,
  pix_key_type text,
  recipient_name text,
  bank_name text,
  document_label text,
  instructions text,
  updated_at timestamptz not null default now()
);

alter table public.portal_payment_settings enable row level security;

drop policy if exists portal_payment_settings_read on public.portal_payment_settings;
drop policy if exists portal_payment_settings_admin_insert on public.portal_payment_settings;
drop policy if exists portal_payment_settings_admin_update on public.portal_payment_settings;

create policy portal_payment_settings_read
on public.portal_payment_settings for select
to authenticated
using (true);

create policy portal_payment_settings_admin_insert
on public.portal_payment_settings for insert
to authenticated
with check (public.is_admin());

create policy portal_payment_settings_admin_update
on public.portal_payment_settings for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

revoke all on table public.portal_payment_settings from anon;
grant select, insert, update on table public.portal_payment_settings to authenticated;

insert into public.portal_payment_settings (id)
values (1)
on conflict (id) do nothing;

insert into public.client_financials (client_id)
select id from public.clients
on conflict (client_id) do nothing;

update public.clients
set display_subtitle = 'Lucasverso21'
where name = 'DC Brasil';

drop policy if exists editorials_client_insert on public.editorials;
create policy editorials_client_insert
on public.editorials for insert
to authenticated
with check (
  client_id = public.current_client_id()
  and created_by = (select auth.uid())
);

drop policy if exists editorial_versions_client_insert on public.editorial_versions;
create policy editorial_versions_client_insert
on public.editorial_versions for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1 from public.editorials e
    where e.id = editorial_versions.editorial_id
      and e.client_id = public.current_client_id()
  )
);

drop policy if exists editorial_items_client_insert on public.editorial_items;
drop policy if exists editorial_items_client_update on public.editorial_items;
drop policy if exists editorial_items_client_delete on public.editorial_items;

create policy editorial_items_client_insert
on public.editorial_items for insert
to authenticated
with check (
  exists (
    select 1
    from public.editorial_versions ev
    join public.editorials e on e.id = ev.editorial_id
    where ev.id = editorial_items.editorial_version_id
      and e.client_id = public.current_client_id()
      and ev.status <> 'approved'
  )
);

create policy editorial_items_client_update
on public.editorial_items for update
to authenticated
using (
  exists (
    select 1
    from public.editorial_versions ev
    join public.editorials e on e.id = ev.editorial_id
    where ev.id = editorial_items.editorial_version_id
      and e.client_id = public.current_client_id()
      and ev.status <> 'approved'
  )
)
with check (
  exists (
    select 1
    from public.editorial_versions ev
    join public.editorials e on e.id = ev.editorial_id
    where ev.id = editorial_items.editorial_version_id
      and e.client_id = public.current_client_id()
      and ev.status <> 'approved'
  )
);

create policy editorial_items_client_delete
on public.editorial_items for delete
to authenticated
using (
  exists (
    select 1
    from public.editorial_versions ev
    join public.editorials e on e.id = ev.editorial_id
    where ev.id = editorial_items.editorial_version_id
      and e.client_id = public.current_client_id()
      and ev.status <> 'approved'
  )
);

grant select, insert on table public.editorials to authenticated;
grant select, insert on table public.editorial_versions to authenticated;
grant select, insert, update, delete on table public.editorial_items to authenticated;
