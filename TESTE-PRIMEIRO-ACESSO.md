# Clímax Portal — teste de primeiro acesso

Abra o `index.html` com Live Server ou um servidor local.

## Simular cliente recém-chegado

Na tela de login, clique em **É meu primeiro acesso**.

- Nome de acesso: `Cliente Teste`
- Código temporário: `CLX-482913`

Depois:
1. crie qualquer senha com 8 ou mais caracteres;
2. confirme a senha;
3. escolha uma pergunta de recuperação;
4. digite uma resposta;
5. clique em **Ativar minha conta**.

A conta entra como **cliente**, vinculada ao workspace fictício **Cliente Teste**.

## Testar recuperação

Saia da conta, clique em **Esqueci minha senha**, informe `Cliente Teste`, responda a pergunta configurada e escolha uma nova senha.

## Resetar a simulação

Se quiser voltar ao estado de cliente sem senha, abra o console do navegador e execute:

```js
localStorage.removeItem('climax-demo-auth-v2'); location.reload();
```

Isso vale somente para o modo demonstração. A versão real usará funções seguras no Supabase.

## Admin de demonstração

Para acessar o painel administrativo enquanto o backend ainda estiver em modo demonstração:

- Nome de acesso: `Leone`
- Senha: `ClimaxDemo#2026`
