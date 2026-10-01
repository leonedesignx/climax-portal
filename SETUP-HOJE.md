# Checklist para colocar 3 clientes no ar hoje

1. Criar projeto Supabase.
2. Rodar `supabase/schema.sql`.
3. Criar usuário Admin em Authentication.
4. Rodar `supabase/make-admin.sql` com o e-mail do Admin.
5. Copiar Project URL + anon key para `config.js` e trocar `DEMO_MODE` para `false`.
6. Testar login Admin localmente.
7. Publicar `invite-client`.
8. Pelo Clímax Portal, criar Cliente 1 + acesso.
9. Repetir para Cliente 2 e Cliente 3.
10. Abrir cada login em janela anônima e confirmar que cada cliente vê somente sua própria conta.
11. Testar no celular: login, Editorial, aprovação e solicitação de alteração.
12. Fazer commit/push no GitHub.
13. Só depois conectar R2 para mídia pesada.
