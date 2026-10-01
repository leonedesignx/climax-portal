-- Clímax Portal — cliente fictício para testes
-- Antes de executar este arquivo, crie em Authentication > Users:
-- Email interno: cliente-teste@auth.climaxportal.com.br
-- Senha temporária de teste: ClimaxTeste#2026
-- Auto Confirm User: ligado

DO $$
DECLARE
  v_user uuid;
  v_client uuid;
  v_editorial uuid;
  v_version uuid;
  v_item1 uuid;
  v_item2 uuid;
  v_item3 uuid;
BEGIN
  SELECT id INTO v_user
  FROM auth.users
  WHERE lower(email)=lower('cliente-teste@auth.climaxportal.com.br')
  LIMIT 1;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Crie primeiro o usuário cliente-teste@auth.climaxportal.com.br em Authentication > Users.';
  END IF;

  SELECT id INTO v_client
  FROM public.clients
  WHERE name='Cliente Teste'
  LIMIT 1;

  IF v_client IS NULL THEN
    INSERT INTO public.clients(name, initials, contact_name, contact_email, category, active)
    VALUES('Cliente Teste','CT','Pessoa Teste','teste@exemplo.com','Social Media',true)
    RETURNING id INTO v_client;
  END IF;

  UPDATE public.profiles
  SET full_name='Cliente Teste', role='client', client_id=v_client, updated_at=now()
  WHERE id=v_user;

  SELECT id INTO v_editorial
  FROM public.editorials
  WHERE client_id=v_client AND month_start='2026-10-01'
  LIMIT 1;

  IF v_editorial IS NULL THEN
    INSERT INTO public.editorials(client_id, month_start, created_by)
    VALUES(v_client,'2026-10-01',v_user)
    RETURNING id INTO v_editorial;
  END IF;

  SELECT id INTO v_version
  FROM public.editorial_versions
  WHERE editorial_id=v_editorial AND version=1
  LIMIT 1;

  IF v_version IS NULL THEN
    INSERT INTO public.editorial_versions(editorial_id, version, status, sent_at, created_by)
    VALUES(v_editorial,1,'waiting',now(),v_user)
    RETURNING id INTO v_version;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.editorial_items WHERE editorial_version_id=v_version) THEN
    INSERT INTO public.editorial_items(editorial_version_id,publish_date,format,title,idea,objective,reference_url,reference_label,production_notes,position)
    VALUES(v_version,'2026-10-05','Carrossel','3 erros que prejudicam uma marca','Carrossel educativo com abertura forte e exemplos visuais.','Educação + autoridade','https://www.instagram.com/','Referência visual','Design limpo, textos curtos e CTA no último slide.',1)
    RETURNING id INTO v_item1;

    INSERT INTO public.editorial_items(editorial_version_id,publish_date,format,title,idea,objective,reference_url,reference_label,production_notes,position)
    VALUES(v_version,'2026-10-12','Reels','Bastidores do processo','Vídeo rápido mostrando etapas de criação e rotina.','Conexão + bastidores','https://www.instagram.com/','Referência de ritmo','Vertical, cortes rápidos, legendas grandes.',2)
    RETURNING id INTO v_item2;

    INSERT INTO public.editorial_items(editorial_version_id,publish_date,format,title,idea,objective,reference_url,reference_label,production_notes,position)
    VALUES(v_version,'2026-10-20','Post','Resultado do mês','Peça simples destacando uma conquista ou resultado.','Prova social','https://www.instagram.com/','Referência de composição','Usar um dado principal em destaque e apoio visual mínimo.',3)
    RETURNING id INTO v_item3;
  ELSE
    SELECT id INTO v_item1 FROM public.editorial_items WHERE editorial_version_id=v_version ORDER BY position LIMIT 1 OFFSET 0;
    SELECT id INTO v_item2 FROM public.editorial_items WHERE editorial_version_id=v_version ORDER BY position LIMIT 1 OFFSET 1;
    SELECT id INTO v_item3 FROM public.editorial_items WHERE editorial_version_id=v_version ORDER BY position LIMIT 1 OFFSET 2;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.contents WHERE client_id=v_client) THEN
    INSERT INTO public.contents(client_id,editorial_item_id,title,type,caption,scheduled_at,status,current_version,created_by)
    VALUES
      (v_client,v_item1,'3 erros que prejudicam uma marca','Carrossel','Legenda fictícia para testar a aprovação do conteúdo.','2026-10-05 18:00:00-03','waiting',1,v_user),
      (v_client,v_item2,'Bastidores do processo','Reels','Legenda fictícia para testar solicitação de alteração.','2026-10-12 19:00:00-03','changes',2,v_user),
      (v_client,v_item3,'Resultado do mês','Post','Conteúdo fictício já aprovado para comparação.','2026-10-20 12:00:00-03','approved',1,v_user);
  END IF;
END $$;

-- Conferência final
select
  p.full_name,
  p.role,
  c.name as client_name,
  u.email as internal_email
from public.profiles p
join auth.users u on u.id=p.id
left join public.clients c on c.id=p.client_id
where lower(u.email)=lower('cliente-teste@auth.climaxportal.com.br');
