# Auditoria técnica — Clímax Portal

## Resumo executivo

### Bugs críticos corrigidos
1. **Fluxos de autenticação conflitantes**: o código misturava ativação por código/Edge Function com o novo fluxo de senha temporária. Foram removidos os caminhos obsoletos e consolidado o fluxo `senha temporária → troca obrigatória → portal`.
2. **Funções duplicadas no login**: havia declarações repetidas de `startFirstAccess()` e `forgotPassword()`, criando comportamento imprevisível. Eliminadas.
3. **Vinculação de cliente quebrada**: o front-end chamava `link_existing_client_user`, mas a função não existia nos SQLs fornecidos. A RPC final foi implementada em `FINAL-HARDENING.sql`, com verificação de Admin e sem expor `service_role`.
4. **Menu mobile bloqueado**: o badge de conexão ficava acima da navegação e interceptava cliques no botão “Mais”. Corrigido com `pointer-events:none` e reposicionamento acima da barra mobile.
5. **Logo clara/escura com bounding boxes diferentes**: as duas versões usavam SVGs com `viewBox` diferentes e provocavam alteração óptica de tamanho/CLS. A logo clara agora deriva do mesmo SVG/base geométrica da escura; apenas a cor do lettering muda.
6. **Tema inicial incompleto**: antes caía sempre em escuro sem respeitar `prefers-color-scheme`. Agora usa preferência salva e, na ausência dela, acompanha o sistema; alterações ficam persistidas no `localStorage`.
7. **Interações sem proteção contra duplo clique**: operações assíncronas importantes foram padronizadas com estado busy/disabled e feedback visual.
8. **Feedback via `alert()` e estados inconsistentes**: substituído por mensagens/toasts em fluxos relevantes, mantendo loading e reversão de estado quando uma persistência falha.
9. **Responsividade/touch**: reforçados alvos mínimos de 44px, inputs de 16px em touch, grids adaptativos e proteção contra overflow horizontal em 320–430px.
10. **Injeção de conteúdo dinâmico**: strings de usuário/dados do backend passam por escape/sanitização nos pontos de `innerHTML` dinâmico e URLs externas são validadas para `http/https`.
11. **Recursos fictícios**: armazenamento R2 e backup de mídia ainda não implementados não são mais apresentados como se estivessem operacionais. A interface indica claramente a limitação e exporta somente JSON dos registros.
12. **Acessibilidade operacional**: foco visível reforçado, `aria-live` para mensagens de autenticação/toasts, Enter no login/troca de senha e Escape para fechar camadas.

## QA executado
- Sintaxe JavaScript validada com `node --check`.
- 152 verificações automatizadas em Chromium headless: **152 aprovadas / 0 falhas**.
- Breakpoints testados: **320, 360, 390, 430, 768 e 1440 px**.
- Rotas exercitadas: Dashboard, Demandas, Clientes, Editorial, Conteúdos, Aprovações, Calendário, Arquivos e Configurações.
- Tema claro/escuro alternado em todos os breakpoints.
- Testes de overflow horizontal em login e todas as rotas.
- Testes de interação: navegação, novo cliente, novo conteúdo, modal, drawer, notificações, perfil e menu mobile.
- Primeiro acesso testado com mock do Supabase: login com senha temporária → tela de nova senha → atualização → sucesso → entrada no portal.

## Limites conhecidos deliberados da V1
- Cloudflare R2/upload de mídia não faz parte deste build.
- Backup de mídia ZIP não faz parte deste build; backup é JSON de registros.
- Recuperação de senha automática não está ativa; a Clímax redefine senha temporária pelo Supabase.
- Disponibilidade do portal depende do GitHub Pages, Supabase e rede do usuário; nenhuma aplicação web pode ter disponibilidade absoluta garantida apenas pelo código do front-end.
