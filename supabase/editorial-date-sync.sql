-- Carry the editorial date to the existing token-protected panel snapshot.
-- Apply after publication-workflow.sql when the panel integration is installed.
-- The existing function definition, token checks, ownership, ACL and search_path
-- are retained. No new entrypoint or public grant is created.
do $migration$
declare original_definition text; patched_definition text;
begin
 if to_regprocedure('public.climax_panel_sync_snapshot(text)') is null then
   raise notice 'Panel snapshot is not installed; nothing to change';
   return;
 end if;
 original_definition := pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 if position('''planned_publish_date''' in original_definition)>0 then return; end if;
 patched_definition := replace(original_definition,
   '''scheduled_at'', c.scheduled_at,',
   '''scheduled_at'', c.scheduled_at, ''planned_publish_date'', coalesce(c.planned_publish_date, (select i.publish_date from public.editorial_items i where i.id=c.editorial_item_id)), ''editorial_item_id'', c.editorial_item_id,');
 if patched_definition = original_definition then
   raise exception 'Expected snapshot date mapping was not found; no changes applied';
 end if;
 execute patched_definition;
end;
$migration$;
