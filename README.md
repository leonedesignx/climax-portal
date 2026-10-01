# Clímax Portal

V1 de produção do portal operacional da Clímax Studio.

## O que já está preparado

- UI responsiva desktop/mobile aprovada
- modo claro e escuro
- login com Supabase Auth
- perfis `admin` e `client`
- isolamento por cliente via RLS
- clientes
- Editorial mensal com versões
- itens de planejamento e referências
- conteúdos
- aprovação e solicitação de alterações
- histórico de reviews no banco
- criação de cliente + acesso via Edge Function `invite-client`
- fallback em modo demonstração enquanto o backend não está conectado

## 1. Criar o projeto Supabase

Crie um projeto vazio no Supabase.

Depois abra **SQL Editor** e execute todo o arquivo:

`supabase/schema.sql`

## 2. Criar sua conta de administrador

Em **Authentication > Users**, crie seu próprio usuário.

Depois abra `supabase/make-admin.sql`, troque `SEU-EMAIL-AQUI` pelo seu e-mail e execute no SQL Editor.

## 3. Conectar o front-end

No Supabase, copie:

- Project URL
- anon/public key

Edite `config.js`:

```js
window.CLIMAX_CONFIG = {
  SUPABASE_URL: 'https://xxxx.supabase.co',
  SUPABASE_ANON_KEY: 'sua-chave-anon',
  DEMO_MODE: false
};
```

A chave `anon` é pública por natureza. A proteção dos dados é feita pelas políticas RLS do banco.

**Nunca coloque a `service_role` no front-end ou no GitHub.**

## 4. Publicar a função de criação de acessos

A pasta `supabase/functions/invite-client` contém a função que cria os logins dos clientes sem expor a `service_role`.

Com o Supabase CLI:

```bash
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy invite-client
```

Depois disso, no painel Admin, **Novo cliente** poderá criar o cliente e o acesso em uma única ação.

## 5. Rodar localmente

Na pasta do projeto:

```bash
python -m http.server 5500
```

Abra:

`http://localhost:5500`

## 6. Subir no GitHub

```bash
git add .
git commit -m "Conecta Clímax Portal ao Supabase"
git push
```

O GitHub Pages atualiza automaticamente.

## Segurança

- cliente não escolhe se é Admin ou Cliente;
- a função do usuário vem de `profiles.role`;
- cliente só lê o `client_id` vinculado à sua conta;
- aprovações usam RPCs auditáveis;
- `service_role` fica somente no ambiente seguro da Edge Function.

## Próxima etapa

Depois do Supabase conectado e dos 3 acessos testados, conectar o Cloudflare R2 para upload privado de imagens e vídeos.
