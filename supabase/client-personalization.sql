begin;
create table public.client_portal_branding (
 client_id uuid primary key references public.clients(id) on delete cascade,
 enabled boolean not null default true,
 primary_color text not null default '#ADF403' check(primary_color ~ '^#[0-9A-Fa-f]{6}$'),
 secondary_color text not null default '#C7FF3B' check(secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
 background_color text not null default '#090A08' check(background_color ~ '^#[0-9A-Fa-f]{6}$'),
 avatar_path text check(avatar_path is null or (split_part(avatar_path,'/',1)=client_id::text and avatar_path ~ '^[0-9a-f-]+/avatar-[0-9a-f-]+[.]jpg$')),
 welcome_name text not null default '' check(length(welcome_name)<=80),
 welcome_greeting text not null default 'neutral' check(welcome_greeting in ('neutral','feminine','masculine')),
 updated_at timestamptz not null default now()
);
alter table public.client_portal_branding enable row level security;
revoke all on public.client_portal_branding from public,anon,authenticated;
grant select,insert,update,delete on public.client_portal_branding to authenticated;
create policy branding_read on public.client_portal_branding for select to authenticated
 using ((select public.is_admin()) or client_id=(select public.current_client_id()));
create policy branding_admin on public.client_portal_branding for all to authenticated
 using ((select public.is_admin())) with check ((select public.is_admin()));

create table public.portal_user_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 theme_mode text not null default 'brand' check(theme_mode in ('brand','light','dark')),
 welcome_dismissed_on date,
 updated_at timestamptz not null default now()
);
alter table public.portal_user_preferences enable row level security;
revoke all on public.portal_user_preferences from public,anon,authenticated;
grant select,insert,update on public.portal_user_preferences to authenticated;
create policy portal_preferences_read on public.portal_user_preferences for select to authenticated
 using (user_id=(select auth.uid()));
create policy portal_preferences_insert on public.portal_user_preferences for insert to authenticated
 with check(user_id=(select auth.uid()) and (welcome_dismissed_on is null or welcome_dismissed_on<=(now() at time zone 'America/Sao_Paulo')::date));
create policy portal_preferences_update on public.portal_user_preferences for update to authenticated
 using(user_id=(select auth.uid()))
 with check(user_id=(select auth.uid()) and (welcome_dismissed_on is null or welcome_dismissed_on<=(now() at time zone 'America/Sao_Paulo')::date));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('client-branding','client-branding',false,5242880,array['image/jpeg'])
 on conflict(id) do nothing;
create policy branding_images_read on storage.objects for select to authenticated
 using(bucket_id='client-branding' and ((select public.is_admin()) or (storage.foldername(name))[1]=(select public.current_client_id())::text));
create policy branding_images_insert on storage.objects for insert to authenticated
 with check(bucket_id='client-branding' and (select public.is_admin()) and exists(select 1 from public.clients where id::text=(storage.foldername(name))[1]));
create policy branding_images_update on storage.objects for update to authenticated
 using(bucket_id='client-branding' and (select public.is_admin()))
 with check(bucket_id='client-branding' and (select public.is_admin()) and exists(select 1 from public.clients where id::text=(storage.foldername(name))[1]));
create policy branding_images_delete on storage.objects for delete to authenticated
 using(bucket_id='client-branding' and (select public.is_admin()));
notify pgrst,'reload schema';
commit;