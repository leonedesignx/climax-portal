-- Clímax Portal — Login V2
-- Fluxo: senha temporária -> troca obrigatória no primeiro acesso.
-- Rode uma única vez no Supabase SQL Editor.

alter table public.profiles
  add column if not exists must_change_password boolean not null default true;

create or replace function public.complete_first_access()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set must_change_password = false
  where id = auth.uid();

  if not found then
    raise exception 'Perfil do usuário não encontrado';
  end if;
end;
$$;

revoke all on function public.complete_first_access() from public;
revoke all on function public.complete_first_access() from anon;
grant execute on function public.complete_first_access() to authenticated;

notify pgrst, 'reload schema';
