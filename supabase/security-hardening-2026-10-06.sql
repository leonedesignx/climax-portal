-- Clímax Portal — hardening de permissões
-- Remove execução anônima de funções internas e fixa search_path de helpers.

revoke execute on function public.current_client_id() from public, anon;
revoke execute on function public.current_role() from public, anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.review_content(uuid,text,text) from public, anon;
revoke execute on function public.review_editorial(uuid,text,text) from public, anon;
revoke execute on function public.send_editorial(uuid) from public, anon;

grant execute on function public.current_client_id() to authenticated, service_role;
grant execute on function public.current_role() to authenticated, service_role;
grant execute on function public.is_admin() to authenticated, service_role;
grant execute on function public.review_content(uuid,text,text) to authenticated, service_role;
grant execute on function public.review_editorial(uuid,text,text) to authenticated, service_role;
grant execute on function public.send_editorial(uuid) to authenticated, service_role;
grant execute on function public.handle_new_user() to service_role;

alter function public.set_updated_at() set search_path = public, pg_temp;
alter function public.set_account_security_updated_at() set search_path = public, pg_temp;
alter function public.set_client_commercials_updated_at() set search_path = public, pg_temp;
alter function public.normalize_access_name(text) set search_path = public, pg_temp;
alter function public.set_profile_access_key() set search_path = public, pg_temp;
