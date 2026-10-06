-- Clímax Portal — UX, revisão, avatar e mídia privada
-- Aplicado ao Supabase de produção em 2026-10-06.

alter table public.profiles
  add column if not exists avatar_path text;

alter table public.contents drop constraint if exists contents_status_check;
alter table public.contents
  add constraint contents_status_check
  check (status = any (array['draft'::text,'material'::text,'waiting'::text,'changes'::text,'rejected'::text,'approved'::text]));

alter table public.reviews drop constraint if exists reviews_action_check;
alter table public.reviews
  add constraint reviews_action_check
  check (action = any (array['approved'::text,'changes'::text,'rejected'::text]));

create or replace function public.review_content(
  p_content_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_content public.contents%rowtype;
begin
  if p_action not in ('approved','changes','rejected') then
    raise exception 'Ação inválida';
  end if;

  select * into v_content from public.contents where id = p_content_id;
  if not found then raise exception 'Conteúdo não encontrado'; end if;

  if not public.is_admin() and v_content.client_id <> public.current_client_id() then
    raise exception 'Acesso negado';
  end if;

  if p_action in ('changes','rejected') and (p_note is null or trim(p_note) = '') then
    raise exception 'Informe o motivo da solicitação';
  end if;

  update public.contents
  set status = case
    when p_action='approved' then 'approved'
    when p_action='rejected' then 'rejected'
    else 'changes'
  end,
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

revoke execute on function public.review_content(uuid,text,text) from public, anon;
grant execute on function public.review_content(uuid,text,text) to authenticated, service_role;

create or replace function public.set_my_avatar_path(p_avatar_path text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Não autenticado'; end if;

  update public.profiles
  set avatar_path = nullif(trim(p_avatar_path),''),
      updated_at = now()
  where id = v_uid;

  if not found then raise exception 'Perfil não encontrado'; end if;
  return nullif(trim(p_avatar_path),'');
end;
$$;

revoke execute on function public.set_my_avatar_path(text) from public, anon;
grant execute on function public.set_my_avatar_path(text) to authenticated, service_role;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('profile-avatars','profile-avatars',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update
set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('client-media','client-media',false,104857600,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update
set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "profile avatars own insert" on storage.objects;
drop policy if exists "profile avatars own update" on storage.objects;
drop policy if exists "profile avatars own delete" on storage.objects;
drop policy if exists "profile avatars own select" on storage.objects;

create policy "profile avatars own insert" on storage.objects for insert to authenticated
with check (bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy "profile avatars own update" on storage.objects for update to authenticated
using (bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid()::text))
with check (bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy "profile avatars own delete" on storage.objects for delete to authenticated
using (bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy "profile avatars own select" on storage.objects for select to authenticated
using (bucket_id='profile-avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));

drop policy if exists "client media scoped select" on storage.objects;
drop policy if exists "client media admin insert" on storage.objects;
drop policy if exists "client media admin update" on storage.objects;
drop policy if exists "client media admin delete" on storage.objects;

create policy "client media scoped select" on storage.objects for select to authenticated
using (bucket_id='client-media' and (public.is_admin() or (storage.foldername(name))[1]=(public.current_client_id()::text)));
create policy "client media admin insert" on storage.objects for insert to authenticated
with check (bucket_id='client-media' and public.is_admin());
create policy "client media admin update" on storage.objects for update to authenticated
using (bucket_id='client-media' and public.is_admin())
with check (bucket_id='client-media' and public.is_admin());
create policy "client media admin delete" on storage.objects for delete to authenticated
using (bucket_id='client-media' and public.is_admin());
