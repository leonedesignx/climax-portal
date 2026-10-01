# Cliente fictício para testes

## Acesso exibido no Clímax Portal
- **Nome de acesso:** Cliente Teste
- **Senha temporária:** ClimaxTeste#2026

O Clímax Portal converte internamente `Cliente Teste` em `cliente-teste@auth.climaxportal.com.br`. O cliente nunca precisa ver esse e-mail técnico.

## Como criar no Supabase
1. Vá em **Authentication > Users > Add user**.
2. Crie o usuário com:
   - Email: `cliente-teste@auth.climaxportal.com.br`
   - Password: `ClimaxTeste#2026`
   - Auto Confirm User: ligado.
3. Abra **SQL Editor**.
4. Execute `supabase/cliente-teste.sql`.
5. Ative o backend no `config.js` e abra o Clímax Portal.
6. Entre com:
   - Nome de acesso: `Cliente Teste`
   - Senha: `ClimaxTeste#2026`

## Dados fictícios criados
O seed cria um cliente chamado **Cliente Teste**, um Editorial de outubro de 2026 aguardando aprovação e três conteúdos com estados diferentes: aguardando aprovação, em alteração e aprovado.
