-- CLÍMAX PORTAL — preparar o acesso do Leone como administrador.
-- 1) Antes, crie manualmente no Authentication > Users um usuário com:
--    email técnico: leone@auth.climaxportal.com.br
--    qualquer senha temporária longa (ela será substituída no primeiro acesso)
--    Auto Confirm User = ligado
-- 2) Depois execute este arquivo.
-- 3) Primeiro acesso no portal:
--    Nome de acesso: Leone
--    Código: CLX-LEON-2026

update public.profiles p
set
  full_name = 'Leone',
  role = 'admin',
  client_id = null,
  access_name = 'Leone',
  access_key = public.normalize_access_name('Leone'),
  auth_email = 'leone@auth.climaxportal.com.br'
from auth.users u
where p.id = u.id
  and lower(u.email) = lower('leone@auth.climaxportal.com.br');

insert into public.account_security (
  user_id,
  activation_code_hash,
  activation_expires_at,
  activated_at,
  recovery_question_key,
  recovery_answer_hash
)
select
  u.id,
  encode(digest(regexp_replace(upper('CLX-LEON-2026'),'[^A-Z0-9]','','g'),'sha256'),'hex'),
  now() + interval '72 hours',
  null,
  null,
  null
from auth.users u
where lower(u.email) = lower('leone@auth.climaxportal.com.br')
on conflict (user_id) do update set
  activation_code_hash = excluded.activation_code_hash,
  activation_expires_at = excluded.activation_expires_at,
  activation_failed_attempts = 0,
  activation_locked_until = null,
  activated_at = null,
  recovery_question_key = null,
  recovery_answer_hash = null,
  recovery_failed_attempts = 0,
  recovery_locked_until = null;

select p.id, p.full_name, p.role, p.access_name, p.access_key, p.auth_email
from public.profiles p
where p.access_key = public.normalize_access_name('Leone');
