# Clímax Portal — build final auditado

Esta pasta é a versão limpa para substituir o projeto publicado no GitHub Pages.

## O que substituir
Copie `index.html` e `config.js` para a raiz do repositório.
Não apague a pasta `.git` do seu repositório local.

## Banco
No Supabase SQL Editor, execute uma vez:

`supabase/FINAL-HARDENING.sql`

O script é idempotente e consolida o fluxo final:
- login por nome de acesso + senha;
- senha temporária no primeiro login;
- troca obrigatória de senha via `must_change_password`;
- RPC segura para concluir o primeiro acesso;
- RPC admin para vincular um usuário Auth já existente a um cliente;
- dados comerciais visíveis somente ao Admin via RLS.

## Fluxo final de primeiro acesso
1. Crie o usuário técnico em Supabase → Authentication → Users com senha temporária e Auto Confirm.
2. Vincule esse usuário a um cliente pelo painel Admin ou pelo SQL já utilizado na implantação.
3. O cliente entra com nome de acesso + senha temporária.
4. O portal detecta `must_change_password=true` e obriga a criação de uma nova senha.
5. Após a troca, `complete_first_access()` marca o perfil como concluído.
6. A senha temporária deixa de funcionar porque a senha do Supabase Auth foi substituída.

## Segurança
- `config.js` contém apenas Project URL + Publishable Key, apropriadas ao front-end.
- Nunca coloque Secret Key ou `service_role` no GitHub Pages.
- O cliente só enxerga dados do próprio `client_id` por RLS.
- Dados comerciais ficam restritos ao Admin.

## Recursos fora da V1
- Upload de mídia / Cloudflare R2 ainda não está conectado.
- O backup disponível exporta JSON dos registros carregados; não exporta vídeos/imagens.
- Recuperação automática por e-mail/pergunta secreta não está ativa. O reset é administrado pela Clímax com uma nova senha temporária.

Veja `HOMOLOGACAO.md` antes do deploy aos clientes.


<!-- deploy-trigger: 2026-10-10 -->
