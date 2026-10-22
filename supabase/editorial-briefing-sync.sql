-- Extend the existing authenticated server bridge without changing its ACL/token checks.
do $patch$
declare original text; patched text;
begin
 original := pg_get_functiondef('public.climax_panel_sync_snapshot(text)'::regprocedure);
 if position('''editorial_briefing''' in original)>0 then return; end if;
 patched := replace(original, '''editorial_item_id'', c.editorial_item_id,',
 $mapping$'editorial_item_id', c.editorial_item_id,
 'editorial_briefing', (select jsonb_build_object(
 'item_id', i.id, 'version_id', v.id, 'version', v.version,
 'editorial_id', e.id, 'month_start', e.month_start, 'approved_at', v.approved_at,
 'title', i.title, 'format', i.format, 'publish_date', i.publish_date,
 'idea', i.idea, 'objective', i.objective,
 'reference_url', i.reference_url, 'reference_label', i.reference_label,
 'caption_draft', i.caption_draft, 'drive_url', i.drive_url,
 'production_notes', i.production_notes, 'feedback', v.feedback)
 from public.editorial_items i
 join public.editorial_versions v on v.id=i.editorial_version_id
 join public.editorials e on e.id=v.editorial_id
 where i.id=c.editorial_item_id and e.client_id=c.client_id and (v.status='approved' or v.approved_at is not null)),
 $mapping$);
 if patched=original then raise exception 'Expected editorial mapping not found'; end if;
 execute patched;
end;
$patch$;