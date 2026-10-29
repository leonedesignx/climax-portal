-- Keep publication formats aligned with the content editor.
begin;
alter table public.contents drop constraint if exists contents_type_check;
alter table public.contents add constraint contents_type_check
  check (type in ('Post', 'Carrossel', 'Reels', 'Story', 'Outro'));
commit;
