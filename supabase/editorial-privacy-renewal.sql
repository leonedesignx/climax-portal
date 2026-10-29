begin;
create table if not exists public.editorial_production_notes (
 item_id uuid primary key references public.editorial_items(id) on delete cascade,
 client_id uuid not null references public.clients(id) on delete cascade,
 notes text not null default '',
 client_visible boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.editorial_production_notes enable row level security;
revoke all on public.editorial_production_notes from anon;
grant select,insert,update,delete on public.editorial_production_notes to authenticated;
create policy production_notes_read on public.editorial_production_notes for select to authenticated
 using ((select public.is_admin()) or (client_visible and client_id=(select public.current_client_id())));
create policy production_notes_admin on public.editorial_production_notes for all to authenticated
 using ((select public.is_admin())) with check ((select public.is_admin()) and exists(
 select 1 from public.editorial_items i join public.editorial_versions v on v.id=i.editorial_version_id join public.editorials e on e.id=v.editorial_id
 where i.id=item_id and e.client_id=editorial_production_notes.client_id));
create index if not exists editorial_production_notes_client_idx on public.editorial_production_notes(client_id);
insert into public.editorial_production_notes(item_id,client_id,notes)
 select i.id,e.client_id,i.production_notes from public.editorial_items i
 join public.editorial_versions v on v.id=i.editorial_version_id join public.editorials e on e.id=v.editorial_id
 where i.production_notes is not null and i.production_notes<>''
 on conflict(item_id) do nothing;
-- Keep the legacy public column empty. Private notes are never delivered through it.
update public.editorial_items set production_notes=null where production_notes is not null;
create function public.enforce_private_production_notes() returns trigger language plpgsql set search_path='' as $fn$
begin
 if new.production_notes is not null and new.production_notes<>'' then
  raise exception 'Atualize o portal para salvar as orientações na área de produção privada.';
 end if;
 new.production_notes:=null;return new;
end;$fn$;
revoke all on function public.enforce_private_production_notes() from public,anon,authenticated;
create trigger enforce_private_production_notes before insert or update of production_notes on public.editorial_items
 for each row execute function public.enforce_private_production_notes();
-- Retain the exact existing token, ownership, ACL and search_path of the panel bridge.
do $patch$
declare original text; patched text;
begin
 original:=pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 patched:=regexp_replace(original,'(''production_notes''\s*,\s*)i\.production_notes',
 '\1(select n.notes from public.editorial_production_notes n where n.item_id=i.id)','g');
 if patched=original then raise exception 'Editorial briefing mapping not found; no migration applied';end if;
 execute patched;
end;$patch$;

create table public.portal_month_archives (
 client_id uuid not null references public.clients(id) on delete cascade,
 month_start date not null check(month_start=date_trunc('month',month_start)::date),
 renewed_at timestamptz not null default now(),
 primary key(client_id,month_start)
);
alter table public.portal_month_archives enable row level security;
revoke all on public.portal_month_archives from anon;
grant select on public.portal_month_archives to authenticated;
create policy month_archives_read on public.portal_month_archives for select to authenticated
 using ((select public.is_admin()) or client_id=(select public.current_client_id()));

create table private.portal_backup_receipts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 month_start date not null, client_id uuid references public.clients(id) on delete cascade,
 fingerprint text not null, manifest jsonb,
 state text not null default 'prepared' check(state in('prepared','downloaded','renewed','complete')),
 cleanup_keys text[] not null default '{}',
 created_at timestamptz not null default now(), downloaded_at timestamptz, renewed_at timestamptz
);
alter table private.portal_backup_receipts enable row level security;
revoke all on private.portal_backup_receipts from public,anon,authenticated;
create index portal_backup_receipts_user_idx on private.portal_backup_receipts(user_id,created_at);

create function private.portal_month_manifest(p_month date,p_client uuid) returns jsonb
language sql stable set search_path='' as $fn$
with
scope_clients as (select * from public.clients where p_client is null or id=p_client),
eds as (select * from public.editorials where client_id in(select id from scope_clients) and month_start=p_month),
evs as (select * from public.editorial_versions where editorial_id in(select id from eds)),
eis as (select * from public.editorial_items where editorial_version_id in(select id from evs)),
cs as (select * from public.contents where client_id in(select id from scope_clients) and
 (editorial_item_id in(select id from eis) or
 (case when planned_publish_date is not null then planned_publish_date
 when scheduled_at is not null then (scheduled_at at time zone 'America/Sao_Paulo')::date
 else (created_at at time zone 'America/Sao_Paulo')::date end >=p_month and
 case when planned_publish_date is not null then planned_publish_date
 when scheduled_at is not null then (scheduled_at at time zone 'America/Sao_Paulo')::date
 else (created_at at time zone 'America/Sao_Paulo')::date end <(p_month+interval '1 month')::date))),
vs as (select * from public.content_versions where content_id in(select id from cs)),
assets as (select * from public.content_preview_assets where content_id in(select id from cs)),
keys as (select media_key as key from vs union select thumbnail_key from vs union select storage_key from assets),
outside_keys as (
 select media_key as key from public.content_versions where content_id not in(select id from cs)
 union select thumbnail_key from public.content_versions where content_id not in(select id from cs)
 union select storage_key from public.content_preview_assets where content_id not in(select id from cs)),
records as (select jsonb_build_object(
 'clients',coalesce((select jsonb_agg(to_jsonb(t) order by id) from scope_clients t),'[]'),
 'editorials',coalesce((select jsonb_agg(to_jsonb(t) order by id) from eds t),'[]'),
 'editorial_versions',coalesce((select jsonb_agg(to_jsonb(t) order by id) from evs t),'[]'),
 'editorial_items',coalesce((select jsonb_agg(to_jsonb(t) order by id) from eis t),'[]'),
 'editorial_production_notes',coalesce((select jsonb_agg(to_jsonb(t) order by item_id) from public.editorial_production_notes t where item_id in(select id from eis)),'[]'),
 'contents',coalesce((select jsonb_agg(to_jsonb(t) order by id) from cs t),'[]'),
 'content_versions',coalesce((select jsonb_agg(to_jsonb(t) order by id) from vs t),'[]'),
 'content_preview_assets',coalesce((select jsonb_agg(to_jsonb(t) order by id) from assets t),'[]'),
 'comments',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.comments t where content_id in(select id from cs) or editorial_version_id in(select id from evs) or editorial_item_id in(select id from eis)),'[]'),
 'reviews',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.reviews t where content_id in(select id from cs) or editorial_version_id in(select id from evs)),'[]'),
 'client_drive_submissions',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.client_drive_submissions t where client_id in(select id from scope_clients)),'[]'),
 'client_financials',coalesce((select jsonb_agg(to_jsonb(t) order by client_id) from public.client_financials t where client_id in(select id from scope_clients)),'[]'),
 'portal_payment_settings',coalesce((select jsonb_agg(to_jsonb(t) order by id) from public.portal_payment_settings t),'[]'),
 'people',coalesce((select jsonb_agg(jsonb_build_object('id',id,'full_name',full_name,'role',role,'client_id',client_id) order by id) from public.profiles where client_id in(select id from scope_clients)),'[]')
) as data)
select jsonb_build_object('format','climax-portal-month-v2','month',to_char(p_month,'YYYY-MM'),'clientId',coalesce(p_client::text,'all'),
 'records',(select data from records),
 'media',coalesce((select jsonb_agg(jsonb_build_object('key',key,'shared',
 (key in(select o.key from outside_keys o where o.key is not null) or split_part(key,'/',1) not in(select id::text from scope_clients))) order by key) from keys where key is not null and key<>''),'[]'),
 'preserved','Cadastros, acessos, financeiro e links permanentes do Drive são preservados pela renovação.')
$fn$;
revoke all on function private.portal_month_manifest(date,uuid) from public,anon,authenticated;

create function public.prepare_portal_month_backup(p_month date,p_client uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare m jsonb; receipt uuid;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso negado';end if;
 if p_month is null or p_month<>date_trunc('month',p_month)::date then raise exception 'Mês inválido';end if;
 if p_client is not null and not exists(select 1 from public.clients where id=p_client) then raise exception 'Cliente inválido';end if;
 m:=private.portal_month_manifest(p_month,p_client);
 insert into private.portal_backup_receipts(user_id,month_start,client_id,fingerprint,manifest)
 values(auth.uid(),p_month,p_client,md5(m::text),m) returning id into receipt;
 return jsonb_build_object('receipt_id',receipt,'manifest',m);
end;$fn$;
revoke all on function public.prepare_portal_month_backup(date,uuid) from public,anon;
grant execute on function public.prepare_portal_month_backup(date,uuid) to authenticated;

create function public.complete_portal_month_backup(p_receipt uuid) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare r private.portal_backup_receipts; m jsonb;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso negado';end if;
 select * into r from private.portal_backup_receipts where id=p_receipt and user_id=auth.uid() for update;
 if not found or r.state not in('prepared','downloaded') then raise exception 'Backup inválido';end if;
 m:=private.portal_month_manifest(r.month_start,r.client_id);
 if md5(m::text)<>r.fingerprint then raise exception 'O mês mudou durante o backup. Gere um novo ZIP antes de renovar.';end if;
 update private.portal_backup_receipts set state='downloaded',downloaded_at=now() where id=r.id;
 return jsonb_build_object('ok',true,'receipt_id',r.id);
end;$fn$;
revoke all on function public.complete_portal_month_backup(uuid) from public,anon;
grant execute on function public.complete_portal_month_backup(uuid) to authenticated;

create function public.renew_portal_month(p_receipt uuid,p_confirm_month text) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare r private.portal_backup_receipts; m jsonb; ed_ids uuid[]; c_ids uuid[]; clean text[]; counts jsonb;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso negado';end if;
 select * into r from private.portal_backup_receipts where id=p_receipt and user_id=auth.uid() for update;
 if not found or r.state not in('downloaded','renewed','complete') then raise exception 'Conclua o backup primeiro';end if;
 if p_confirm_month is distinct from to_char(r.month_start,'YYYY-MM') then raise exception 'Confirme o mês correto';end if;
 if r.state in('renewed','complete') then return jsonb_build_object('ok',true,'cleanup_keys',to_jsonb(r.cleanup_keys),'already_renewed',true);end if;
 -- Brief transaction: block concurrent edits while checking the exact exported manifest.
 lock table public.editorials,public.editorial_versions,public.editorial_items,public.editorial_production_notes,
 public.contents,public.content_versions,public.content_preview_assets,public.comments,public.reviews,
 public.clients,public.client_drive_submissions,public.client_financials,public.portal_payment_settings,public.profiles
 in share row exclusive mode;
 m:=private.portal_month_manifest(r.month_start,r.client_id);
 if md5(m::text)<>r.fingerprint then raise exception 'Há alterações depois do backup. Gere outro ZIP antes de renovar.';end if;
 select coalesce(array_agg((x->>'id')::uuid),'{}') into ed_ids from jsonb_array_elements(m->'records'->'editorials') x;
 select coalesce(array_agg((x->>'id')::uuid),'{}') into c_ids from jsonb_array_elements(m->'records'->'contents') x;
 select coalesce(array_agg(x->>'key'),'{}') into clean from jsonb_array_elements(m->'media') x where not (x->>'shared')::boolean;
 counts:=jsonb_build_object('editorials',cardinality(ed_ids),'contents',cardinality(c_ids),'media',cardinality(clean));
 -- Cascades remove only child versions, previews, reviews, notes and comments of these exact records.
 delete from public.contents where id=any(c_ids);
 delete from public.editorials where id=any(ed_ids);
 insert into public.portal_month_archives(client_id,month_start)
 select (x->>'id')::uuid,r.month_start from jsonb_array_elements(m->'records'->'clients') x
 on conflict(client_id,month_start) do update set renewed_at=now();
 update private.portal_backup_receipts set state='renewed',renewed_at=now(),cleanup_keys=clean,manifest=null where id=r.id;
 return jsonb_build_object('ok',true,'counts',counts,'cleanup_keys',to_jsonb(clean));
end;$fn$;
revoke all on function public.renew_portal_month(uuid,text) from public,anon;
grant execute on function public.renew_portal_month(uuid,text) to authenticated;

create function public.portal_month_cleanup_keys(p_receipt uuid) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare r private.portal_backup_receipts; safe text[];
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso negado';end if;
 select * into r from private.portal_backup_receipts where id=p_receipt and user_id=auth.uid();
 if not found or r.state not in('renewed','complete') then raise exception 'Renovação inválida';end if;
 select coalesce(array_agg(k),'{}') into safe from unnest(r.cleanup_keys) k
 where not exists(select 1 from public.content_versions v where v.media_key=k or v.thumbnail_key=k)
 and not exists(select 1 from public.content_preview_assets a where a.storage_key=k);
 return jsonb_build_object('keys',to_jsonb(safe));
end;$fn$;
revoke all on function public.portal_month_cleanup_keys(uuid) from public,anon;
grant execute on function public.portal_month_cleanup_keys(uuid) to authenticated;

create function public.finish_portal_month_cleanup(p_receipt uuid) returns jsonb
language plpgsql security definer set search_path='' as $fn$
declare r private.portal_backup_receipts;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Acesso negado';end if;
 select * into r from private.portal_backup_receipts where id=p_receipt and user_id=auth.uid() for update;
 if not found or r.state not in('renewed','complete') then raise exception 'Renovação inválida';end if;
 if exists(select 1 from storage.objects o where o.bucket_id='client-media' and o.name=any(r.cleanup_keys)
 and not exists(select 1 from public.content_versions v where v.media_key=o.name or v.thumbnail_key=o.name)
 and not exists(select 1 from public.content_preview_assets a where a.storage_key=o.name)) then
 raise exception 'Ainda há arquivos pendentes. Tente concluir a limpeza novamente.';end if;
 update private.portal_backup_receipts set state='complete',cleanup_keys='{}' where id=r.id;
 return jsonb_build_object('ok',true);
end;$fn$;
revoke all on function public.finish_portal_month_cleanup(uuid) from public,anon;
grant execute on function public.finish_portal_month_cleanup(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
