-- Drive library: main folder managed by admins; extra links scoped to each client.
alter table public.clients add column drive_folder_url text;
alter table public.clients add constraint clients_drive_folder_url_check check (
 drive_folder_url is null or (length(drive_folder_url) <= 2048 and drive_folder_url ~ '^https://drive[.]google[.]com/[^[:space:]<>]*$')
);
create table public.client_drive_submissions (
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null references public.clients(id) on delete cascade,
 submitted_by uuid not null default auth.uid() references public.profiles(id),
 drive_url text not null check (length(drive_url) <= 2048 and drive_url ~ '^https://(drive|docs)[.]google[.]com/[^[:space:]<>]*$'),
 note text not null default '' check (length(note) <= 1000),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz
);
create index client_drive_submissions_client_created_idx on public.client_drive_submissions(client_id, created_at desc);
create index client_drive_submissions_submitted_by_idx on public.client_drive_submissions(submitted_by);
alter table public.client_drive_submissions enable row level security;
revoke all on public.client_drive_submissions from public, anon, authenticated;
grant select on public.client_drive_submissions to authenticated;
grant insert (client_id,drive_url,note) on public.client_drive_submissions to authenticated;
grant update (reviewed_at) on public.client_drive_submissions to authenticated;
create policy drive_submissions_read on public.client_drive_submissions for select to authenticated
 using ((select public.is_admin()) or client_id=(select public.current_client_id()));
create policy drive_submissions_insert on public.client_drive_submissions for insert to authenticated
 with check (client_id=(select public.current_client_id()) and submitted_by=(select auth.uid()) and reviewed_at is null);
create policy drive_submissions_admin_review on public.client_drive_submissions for update to authenticated
 using ((select public.is_admin())) with check ((select public.is_admin()));
