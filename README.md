# Clímax Portal

Portal privado da Clímax Studio para planejamento editorial, produção, aprovações, calendário, clientes e arquivos.

## V1

- Admin e Cliente com interfaces distintas
- Login por nome de acesso + senha
- Primeiro acesso por código temporário
- Cliente cria a própria senha
- Recuperação por pergunta de segurança + fallback administrativo
- Isolamento de clientes com Supabase RLS
- Editorial mensal versionado
- Conteúdos e aprovações
- Mobile-first para clientes
- Dark/light mode

## Configuração

Leia `SETUP-V1-PRODUCAO.md`.

## Arquivos importantes

- `index.html` — aplicação web
- `config.js` — configuração pública do Supabase
- `supabase/schema.sql` — instalação limpa
- `supabase/migration-auth-v1.sql` — atualização para quem já rodou o schema inicial
- `supabase/bootstrap-leone.sql` — primeiro administrador
- `supabase/functions/` — funções seguras de criação/ativação/recuperação de acesso

## Importante

Nunca coloque Secret Key/service_role no front-end ou no GitHub.
