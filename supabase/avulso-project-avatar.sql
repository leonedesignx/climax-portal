begin;
alter table public.avulso_projects add column avatar_path text not null default '' check(avatar_path='' or avatar_path like id::text||'/profile/%');
do $patch$ declare definition text; begin
 definition:=pg_get_functiondef('public.avulso_project_payload(text)'::regprocedure);
 if strpos(definition,$old$'title',p.title,$old$)=0 then raise exception 'Payload inesperado. Nenhuma alteração aplicada.';end if;
 execute replace(definition,$old$'title',p.title,$old$,$new$'title',p.title,'avatar_path',p.avatar_path,$new$);
end;$patch$;
create or replace function public.avulso_can_read_media(p_path text) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.avulso_projects p where p.id=public.avulso_token_project((nullif(current_setting('request.headers',true),'')::jsonb)->>'x-avulso-token') and ((p.avatar_path<>'' and p.avatar_path=p_path) or exists(select 1 from public.avulso_entries e where e.project_id=p.id and e.published and p_path=any(e.media_paths))))
$$;
revoke all on function public.avulso_can_read_media(text) from public;
grant execute on function public.avulso_can_read_media(text) to anon,authenticated;
commit;