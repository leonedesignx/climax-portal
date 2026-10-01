# Clímax Portal — colocar a V1 em produção

Este guia parte do ponto em que o `schema.sql` inicial já foi executado no Supabase.

## 1. Atualizar o banco

No Supabase: **SQL Editor → New query**.

Cole todo o conteúdo de:

`supabase/migration-auth-v1.sql`

Clique em **Run**. O esperado é `Success. No rows returned`.

## 2. Criar o acesso administrador do Leone

Em **Authentication → Users → Add user** crie:

- Email técnico: `leone@auth.climaxportal.com.br`
- Senha: qualquer senha temporária longa/aleatória (não será a senha final)
- Auto Confirm User: ligado

Depois execute no SQL Editor:

`supabase/bootstrap-leone.sql`

Primeiro acesso do Leone no portal:

- Nome de acesso: `Leone`
- Código: `CLX-LEON-2026`

O portal pedirá para criar a senha definitiva e configurar a recuperação.

## 3. Publicar as Edge Functions

Funções necessárias:

- `activate-account` — valida primeiro acesso e define a senha escolhida pelo usuário.
- `account-recovery` — pergunta de segurança e troca de senha.
- `create-access` — somente Admin; cria cliente + usuário + código temporário.
- `reset-access` — somente Admin; gera um novo primeiro acesso quando necessário.

### Pela Supabase CLI

Na raiz do projeto, depois de autenticar e vincular o projeto:

```bash
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy activate-account --no-verify-jwt
supabase functions deploy account-recovery --no-verify-jwt
supabase functions deploy create-access --no-verify-jwt
supabase functions deploy reset-access --no-verify-jwt
```

As funções usam as variáveis padrão do Supabase. Chaves secretas nunca devem ir para o navegador ou GitHub.

## 4. Ligar o front-end ao Supabase

No Dashboard do Supabase, use **Connect** e copie:

- Project URL
- Publishable key (`sb_publishable_...`)

Edite `config.js`:

```js
window.CLIMAX_CONFIG = {
  SUPABASE_URL: 'https://SEU-PROJETO.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_xxxxx',
  SUPABASE_ANON_KEY: '',
  DEMO_MODE: false
};
```

A Publishable Key pode ficar no navegador. A segurança dos dados depende das políticas RLS. Nunca coloque Secret Key/service_role no front-end.

## 5. Testar primeiro acesso do Leone

Abra o Clímax Portal publicado.

Clique em **É meu primeiro acesso** e use:

- Nome: `Leone`
- Código: `CLX-LEON-2026`

Crie sua senha final e a pergunta de recuperação. Depois confirme que o login leva ao **Painel administrativo**.

## 6. Criar Cliente Teste pela interface

No Admin: **Clientes → Novo cliente**.

Preencha, por exemplo:

- Nome: Cliente Teste
- Responsável: Cliente recém-chegado
- Nome de acesso: Cliente Teste

Clique em **Criar cliente e primeiro acesso**.

O Clímax Portal exibirá um código `CLX-XXXX-XXXX`. Copie-o. Abra o portal em janela anônima e simule o primeiro acesso do cliente.

Valide:

- cria a própria senha;
- configura recuperação;
- entra novamente com nome + senha;
- vê somente o próprio cliente;
- consegue aprovar/solicitar alteração;
- não enxerga dados de outros clientes.

## 7. Criar os 3 clientes reais

Use o mesmo botão **Novo cliente**. O cliente recebe apenas:

- Nome de acesso
- Código temporário

Nunca precisa receber uma senha criada pela Clímax.

Nomes acordados:

- `dcbrasil`
- `Transportadora Gonçalo`
- `Iasmim França`

Os dados comerciais devem ser preenchidos no Admin e ficam protegidos pelas políticas de administrador; não devem ser escritos no código-fonte público.

## 8. Publicar no GitHub Pages

Depois de atualizar os arquivos no repositório:

```bash
git add .
git commit -m "Finaliza autenticação V1 do Climax Portal"
git push origin main
```

Espere o Pages concluir o deploy e force atualização com `Ctrl + F5`.

## 9. Teste de segurança obrigatório

Antes de enviar os acessos reais:

1. Admin entra e vê todos os clientes.
2. Cliente Teste entra e vê somente o Cliente Teste.
3. Copie o ID/URL de um conteúdo de outro cliente e tente acessá-lo logado como Cliente Teste.
4. O banco deve negar o acesso via RLS.
5. Teste no celular em janela anônima.
6. Teste recuperação de senha.
7. Teste código de primeiro acesso incorreto 5 vezes e confirme o bloqueio temporário.

## Segurança

- Senhas são administradas pelo Supabase Auth.
- Respostas de recuperação são armazenadas com PBKDF2, nunca em texto puro.
- Códigos de primeiro acesso são armazenados como hash e expiram em 72 horas.
- Após 5 tentativas incorretas, primeiro acesso/recuperação ficam temporariamente bloqueados.
- Existe uma saída administrativa por `reset-access` caso a pessoa esqueça também a resposta de recuperação.
