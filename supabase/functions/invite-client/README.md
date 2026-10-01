# invite-client

Função administrativa para criar o login do cliente sem expor a `service_role` no navegador.

Deploy com Supabase CLI:

```bash
supabase login
supabase link --project-ref SEU_PROJECT_REF
supabase functions deploy invite-client
```

A função usa `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` no ambiente da função. Nunca copie a service role para `config.js`.
