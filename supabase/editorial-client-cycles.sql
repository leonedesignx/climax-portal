begin;
alter table public.clients add column if not exists editorial_cycle_day smallint not null default 1 check(editorial_cycle_day between 1 and 28);
alter table public.editorials add column if not exists period_start date;
alter table public.editorials add column if not exists period_end date;
alter table public.contents add column if not exists show_in_feed boolean not null default true;

create or replace function private.climax_editorial_cycle_label(p_editorial uuid) returns text language sql stable set search_path='' as $$
 select case when cl.editorial_cycle_day>1 or e.period_start is not null then
 'Ciclo '||to_char(coalesce(e.period_start,(e.month_start-interval '1 month')::date+cl.editorial_cycle_day-1),'DD/MM/YYYY')||' a '||
 to_char(coalesce(e.period_end,e.month_start+cl.editorial_cycle_day-2),'DD/MM/YYYY') else null end
 from public.editorials e join public.clients cl on cl.id=e.client_id where e.id=p_editorial
$$;
revoke all on function private.climax_editorial_cycle_label(uuid) from public,anon,authenticated;
do $patch$
declare original text;patched text;
begin
 original:=pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 if position('''cycle_label''' in original)=0 then
 patched:=regexp_replace(original,'(''month_start''\s*,\s*e\.month_start\s*,)',
 '\1''cycle_label'',private.climax_editorial_cycle_label(e.id),''cycle_start'',e.period_start,''cycle_end'',e.period_end,');
 if patched=original then raise exception 'Cycle snapshot mapping missing';end if;
 execute patched;
 end if;
end $patch$;
commit;
