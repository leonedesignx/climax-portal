-- Clímax: isolated, link-scoped one-off projects. No access to recurring clients.
begin;
create table public.avulso_projects (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(name) between 1 and 120),
 title text not null check(length(title) between 1 and 180),
 access_token text not null unique default encode(extensions.gen_random_bytes(32),'hex'),
 active boolean not null default true,
 expires_at timestamptz not null default now()+interval '30 days',
 contact_url text not null default '' check(contact_url='' or contact_url ~ '^https://(wa[.]me|www[.]instagram[.]com)/[^[:space:]<>]+$'),
 editorial_revision integer not null default 1,
 editorial_status text not null default 'draft' check(editorial_status in ('draft','waiting','approved','changes','rejected')),
 created_at timestamptz not null default now(),
 created_by uuid not null default auth.uid() references auth.users(id)
);
create table public.avulso_entries (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.avulso_projects(id) on delete cascade,
 kind text not null check(kind in ('editorial','delivery')),
 title text not null check(length(title) between 1 and 180),
 format text not null default 'Post',
 publish_date date,
 idea text not null default '' check(length(idea)<=30000),
 objective text not null default '' check(length(objective)<=5000),
 caption text not null default '' check(length(caption)<=15000),
 reference_url text not null default '' check(reference_url='' or reference_url ~ '^https://[^[:space:]<>]+$'),
 drive_url text not null default '' check(drive_url='' or drive_url ~ '^https://[^[:space:]<>]+$'),
 media_paths text[] not null default '{}',
 published boolean not null default false,
 position integer not null default 0,
 revision integer not null default 1,
 review_status text not null default 'waiting' check(review_status in ('waiting','approved','changes','rejected')),
 created_at timestamptz not null default now(),
 check(cardinality(media_paths)<=20)
);
create index avulso_entries_project_idx on public.avulso_entries(project_id,kind,position);
create table public.avulso_reviews (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null references public.avulso_projects(id),
 entry_id uuid references public.avulso_entries(id) on delete set null,
 scope text not null check(scope in ('editorial','delivery')),
 revision integer not null,
 action text not null check(action in ('approved','changes','rejected')),
 note text not null default '' check(length(note)<=3000),
 created_at timestamptz not null default now()
);
create index avulso_reviews_project_idx on public.avulso_reviews(project_id,created_at desc);
alter table public.avulso_projects enable row level security;
alter table public.avulso_entries enable row level security;
alter table public.avulso_reviews enable row level security;
revoke all on public.avulso_projects,public.avulso_entries,public.avulso_reviews from anon,authenticated;
grant select,insert,update on public.avulso_projects,public.avulso_entries to authenticated;
grant select on public.avulso_reviews to authenticated;
create policy avulso_projects_admin on public.avulso_projects for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy avulso_entries_admin on public.avulso_entries for all to authenticated using ((select public.is_admin())) with check ((select public.is_admin()));
create policy avulso_reviews_admin on public.avulso_reviews for select to authenticated using ((select public.is_admin()));

create function public.avulso_entry_revision() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if tg_op='UPDATE' then
  if new.project_id<>old.project_id or new.kind<>old.kind then raise exception 'O vínculo do item não pode mudar.';end if;
  if (to_jsonb(new)-'revision'-'review_status') is distinct from (to_jsonb(old)-'revision'-'review_status') then
   new.revision:=old.revision+1;new.review_status:='waiting';
  end if;
 end if;
 if exists(select 1 from unnest(new.media_paths) p where p not like new.project_id::text||'/'||new.id::text||'/%') then raise exception 'Arquivo fora do projeto.';end if;
 if new.kind='editorial' and (tg_op='INSERT' or new.revision<>old.revision) then
  update public.avulso_projects set editorial_revision=editorial_revision+1,
   editorial_status=case when new.published or editorial_status<>'draft' then 'waiting' else 'draft' end where id=new.project_id;
 end if;
 return new;
end;$$;
create trigger avulso_entry_revision before insert or update on public.avulso_entries for each row execute function public.avulso_entry_revision();

create function public.avulso_token_project(p_token text) returns uuid language sql stable security definer set search_path=public,pg_temp as $$
 select id from public.avulso_projects where length(p_token)=64 and access_token=p_token and active and expires_at>now()
$$;
revoke all on function public.avulso_token_project(text) from public,anon,authenticated;

create function public.avulso_project_payload(p_token text) returns jsonb language plpgsql volatile security definer set search_path=public,pg_temp as $$
declare pid uuid; result jsonb;
begin
 pid:=public.avulso_token_project(p_token);
 if pid is null then raise exception 'Este link expirou ou foi desativado. Solicite um novo link à Clímax.';end if;
 select jsonb_build_object('id',p.id,'name',p.name,'title',p.title,'contact_url',p.contact_url,
  'editorial_revision',p.editorial_revision,'editorial_status',p.editorial_status,
  'entries',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'title',e.title,'format',e.format,
   'publish_date',e.publish_date,'idea',e.idea,'objective',e.objective,'caption',e.caption,'reference_url',e.reference_url,
   'drive_url',e.drive_url,'media_paths',e.media_paths,'revision',e.revision,'review_status',e.review_status) order by e.position,e.created_at)
   from public.avulso_entries e where e.project_id=p.id and e.published),'[]'::jsonb),
  'reviews',coalesce((select jsonb_agg(jsonb_build_object('scope',r.scope,'entry_id',r.entry_id,'revision',r.revision,'action',r.action,'note',r.note,'created_at',r.created_at) order by r.created_at desc)
   from (select * from public.avulso_reviews where project_id=pid order by created_at desc limit 100) r),'[]'::jsonb)) into result
 from public.avulso_projects p where p.id=pid;
 return result;
end;$$;
revoke all on function public.avulso_project_payload(text) from public;
grant execute on function public.avulso_project_payload(text) to anon,authenticated;

create function public.avulso_review(p_token text,p_scope text,p_entry_id uuid,p_revision integer,p_action text,p_note text default '') returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare pid uuid; p public.avulso_projects; e public.avulso_entries; current_status text;
begin
 pid:=public.avulso_token_project(p_token);
 if pid is null then raise exception 'Este link expirou ou foi desativado.';end if;
 select * into p from public.avulso_projects where id=pid for update;
 if not p.active or p.expires_at<=now() then raise exception 'Este link expirou ou foi desativado.';end if;
 if p_action not in ('approved','changes','rejected') or length(coalesce(p_note,''))>3000 then raise exception 'Resposta inválida.';end if;
 if p_action in ('changes','rejected') and length(trim(coalesce(p_note,'')))=0 then raise exception 'Conte o que precisa mudar.';end if;
 if p_scope='editorial' then
  if p_entry_id is not null or p.editorial_revision<>p_revision or not exists(select 1 from public.avulso_entries where project_id=pid and kind='editorial' and published) then raise exception 'O editorial foi atualizado. Recarregue antes de aprovar.';end if;
  current_status:=p.editorial_status;
  if current_status='draft' then raise exception 'Editorial ainda não liberado.';end if;
  if current_status<>'waiting' then return public.avulso_project_payload(p_token);end if;
  update public.avulso_projects set editorial_status=p_action where id=pid;
 elsif p_scope='delivery' then
  select * into e from public.avulso_entries where id=p_entry_id and project_id=pid and kind='delivery' and published for update;
  if not found or e.revision<>p_revision then raise exception 'A entrega foi atualizada. Recarregue antes de aprovar.';end if;
  if e.review_status<>'waiting' then return public.avulso_project_payload(p_token);end if;
  update public.avulso_entries set review_status=p_action where id=e.id;
 else raise exception 'Tipo de revisão inválido.';
 end if;
 insert into public.avulso_reviews(project_id,entry_id,scope,revision,action,note) values(pid,p_entry_id,p_scope,p_revision,p_action,trim(coalesce(p_note,'')));
 return public.avulso_project_payload(p_token);
end;$$;
revoke all on function public.avulso_review(text,text,uuid,integer,text,text) from public;
grant execute on function public.avulso_review(text,text,uuid,integer,text,text) to anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('avulso-media','avulso-media',false,52428800,array['image/jpeg','image/png','image/webp','video/mp4','application/pdf']) on conflict(id) do nothing;
create function public.avulso_can_read_media(p_path text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.avulso_projects p join public.avulso_entries e on e.project_id=p.id
 where p.id=public.avulso_token_project((current_setting('request.headers',true)::jsonb)->>'x-avulso-token') and e.published and p_path=any(e.media_paths))
$$;
revoke all on function public.avulso_can_read_media(text) from public;
grant execute on function public.avulso_can_read_media(text) to anon,authenticated;
create policy avulso_media_admin on storage.objects for all to authenticated using(bucket_id='avulso-media' and (select public.is_admin())) with check(bucket_id='avulso-media' and (select public.is_admin()));
create policy avulso_media_guest on storage.objects for select to anon,authenticated using(bucket_id='avulso-media' and public.avulso_can_read_media(name));
commit;