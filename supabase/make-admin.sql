-- Depois de criar sua conta em Authentication > Users, troque o e-mail abaixo
-- e execute este bloco para transformar SUA conta em administradora.
update public.profiles p
set role = 'admin', client_id = null, full_name = coalesce(p.full_name, 'Leone')
from auth.users u
where p.id = u.id
  and lower(u.email) = lower('SEU-EMAIL-AQUI');
