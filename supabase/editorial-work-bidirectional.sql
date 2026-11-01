begin;
alter table public.contents add column if not exists panel_deleted_at timestamptz;
alter table public.editorial_items add column if not exists panel_deleted_at timestamptz;

create or replace function private.climax_work_revision(p_content uuid) returns text
language sql stable security definer set search_path='' as $$
 select md5(jsonb_build_array(to_jsonb(c),to_jsonb(i),to_jsonb(n))::text)
 from public.contents c left join public.editorial_items i on i.id=c.editorial_item_id
 left join public.editorial_production_notes n on n.item_id=i.id where c.id=p_content
$$;
revoke all on function private.climax_work_revision(uuid) from public,anon,authenticated;

create or replace function public.climax_panel_update_work(p_token text,p_content uuid,p_revision text,p_action text,p_patch jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare expected text; c public.contents%rowtype; i public.editorial_items%rowtype; key text;
begin
 select sync_token into expected from private.climax_panel_sync_config where id=1;
 if expected is null or p_token is distinct from expected then raise exception 'unauthorized' using errcode='42501'; end if;
 select * into c from public.contents where id=p_content for update;
 if not found then raise exception 'O conteúdo foi excluído no portal. Atualize a gestão.'; end if;
 select * into i from public.editorial_items where id=c.editorial_item_id for update;
 if i.id is null then raise exception 'Este conteúdo não possui um editorial vinculado.'; end if;
 perform 1 from public.editorial_production_notes where item_id=i.id for update;
 if p_revision is null or private.climax_work_revision(c.id) is distinct from p_revision then
 raise exception 'O conteúdo mudou no portal. Atualize a gestão antes de salvar.' using errcode='40001'; end if;
 if p_action='delete' then
 update public.contents set panel_deleted_at=now(),updated_at=now() where id=c.id;
 update public.editorial_items set panel_deleted_at=now(),updated_at=now() where id=i.id;
 elsif p_action='restore' then
 update public.contents set panel_deleted_at=null,updated_at=now() where id=c.id;
 update public.editorial_items set panel_deleted_at=null,updated_at=now() where id=i.id;
 elsif p_action='update' then
 if c.panel_deleted_at is not null or i.panel_deleted_at is not null then raise exception 'Item removido. Restaure antes de editar.'; end if;
 if jsonb_typeof(p_patch)<>'object' then raise exception 'Dados inválidos'; end if;
 for key in select jsonb_object_keys(p_patch) loop
 if key not in ('title','format','publish_date','idea','objective','reference_url','reference_label','caption_draft','drive_url','production_notes','client_visible','scheduled_at') then raise exception 'Campo não permitido: %',key; end if;
 end loop;
 if p_patch ? 'title' and length(trim(p_patch->>'title'))=0 then raise exception 'Informe o título'; end if;
 if p_patch ? 'format' and p_patch->>'format' not in ('Post','Carrossel','Reels','Story') then raise exception 'Formato inválido'; end if;
 foreach key in array array['reference_url','drive_url'] loop
 if p_patch ? key and coalesce(p_patch->>key,'')<>'' and p_patch->>key !~* '^https?://' then raise exception 'Use um link http ou https'; end if;
 end loop;
 update public.editorial_items set
 title=case when p_patch?'title' then trim(p_patch->>'title') else title end,
 format=case when p_patch?'format' then p_patch->>'format' else format end,
 publish_date=case when p_patch?'publish_date' then (p_patch->>'publish_date')::date else publish_date end,
 idea=case when p_patch?'idea' then p_patch->>'idea' else idea end,
 objective=case when p_patch?'objective' then p_patch->>'objective' else objective end,
 reference_url=case when p_patch?'reference_url' then nullif(p_patch->>'reference_url','') else reference_url end,
 reference_label=case when p_patch?'reference_label' then p_patch->>'reference_label' else reference_label end,
 caption_draft=case when p_patch?'caption_draft' then p_patch->>'caption_draft' else caption_draft end,
 drive_url=case when p_patch?'drive_url' then nullif(p_patch->>'drive_url','') else drive_url end,
 updated_at=now() where id=i.id;
 if p_patch?'production_notes' or p_patch?'client_visible' then
 insert into public.editorial_production_notes(item_id,client_id,notes,client_visible,updated_at)
 values(i.id,c.client_id,coalesce(p_patch->>'production_notes',''),coalesce((p_patch->>'client_visible')::boolean,false),now())
 on conflict(item_id) do update set notes=case when p_patch?'production_notes' then excluded.notes else editorial_production_notes.notes end,
 client_visible=case when p_patch?'client_visible' then excluded.client_visible else editorial_production_notes.client_visible end,updated_at=now();
 end if;
 update public.contents set title=case when p_patch?'title' then trim(p_patch->>'title') else title end,
 type=case when p_patch?'format' then p_patch->>'format' else type end,
 caption=case when p_patch?'caption_draft' then p_patch->>'caption_draft' else caption end,
 drive_url=case when p_patch?'drive_url' then nullif(p_patch->>'drive_url','') else drive_url end,
 planned_publish_date=case when p_patch?'publish_date' then (p_patch->>'publish_date')::date else planned_publish_date end,
 scheduled_at=case when p_patch?'scheduled_at' then (p_patch->>'scheduled_at')::timestamptz when p_patch?'publish_date' and scheduled_at is not null then (((p_patch->>'publish_date')::date::text||' '||(scheduled_at at time zone 'America/Sao_Paulo')::time::text)::timestamp at time zone 'America/Sao_Paulo') else scheduled_at end,
 updated_at=now() where id=c.id;
 else raise exception 'Ação inválida'; end if;
 return jsonb_build_object('ok',true,'revision',private.climax_work_revision(c.id),'content_id',c.id);
end $fn$;
revoke all on function public.climax_panel_update_work(text,uuid,text,text,jsonb) from public;
grant execute on function public.climax_panel_update_work(text,uuid,text,text,jsonb) to anon,authenticated;

do $patch$
declare original text; patched text;
begin
 original:=pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 if position('''sync_revision''' in original)=0 then
 patched:=replace(original,'''editorial_item_id'', c.editorial_item_id,',
 '''editorial_item_id'', c.editorial_item_id, ''sync_revision'', private.climax_work_revision(c.id), ''panel_deleted_at'', c.panel_deleted_at,');
 if patched=original then raise exception 'Snapshot mapping missing';end if;
 execute patched;
 end if;
 original:=pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 if position('''client_visible''' in original)=0 then
 patched:=replace(original,'''feedback'',v.feedback',
 '''client_visible'',coalesce((select n.client_visible from public.editorial_production_notes n where n.item_id=i.id),false),''item_deleted_at'',i.panel_deleted_at,''feedback'',v.feedback');
 if patched=original then raise exception 'Briefing mapping missing';end if;
 execute patched;
 end if;
end $patch$;

commit;
