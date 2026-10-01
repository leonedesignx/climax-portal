# Checklist de homologação final — Clímax Portal

## Banco e autenticação
- [ ] Executar `supabase/FINAL-HARDENING.sql` sem erro.
- [ ] Abrir em janela anônima: somente a tela de login deve aparecer.
- [ ] Conta com `must_change_password=true`: senha temporária → criação obrigatória de nova senha → sucesso → portal.
- [ ] Sair e confirmar que a senha temporária não autentica mais.
- [ ] Confirmar que a nova senha autentica normalmente.
- [ ] Testar Leone/Admin e cada cliente real.
- [ ] Confirmar que um cliente não vê clientes, conteúdos ou editoriais de outra conta.

## Fluxos
- [ ] Criar conteúdo como Admin.
- [ ] Alterar status e confirmar persistência após F5.
- [ ] Cliente aprovar conteúdo.
- [ ] Cliente solicitar alteração com comentário.
- [ ] Editar/duplicar item editorial.
- [ ] Enviar editorial para aprovação.
- [ ] Cliente aprovar editorial / solicitar ajustes.
- [ ] Criar nova versão após aprovação.
- [ ] Abrir histórico.
- [ ] Testar busca e notificações.
- [ ] Testar modal de suporte e cópia.
- [ ] Gerar backup JSON.

## UI/UX
- [ ] Alternar claro/escuro e recarregar: tema deve persistir.
- [ ] Sem preferência salva, confirmar que segue o tema do sistema.
- [ ] Confirmar que logos clara/escura mantêm o mesmo tamanho e alinhamento.
- [ ] Testar 320, 360, 390, 430, 768 e desktop sem scroll horizontal.
- [ ] Testar menu “Mais” no mobile — nenhum badge deve bloquear o toque.
- [ ] Testar teclado: foco visível, Enter no login e Escape em modais/drawer.
- [ ] Testar Chrome/Edge desktop e Safari/Chrome em celular real.
- [ ] DevTools Console sem erros durante navegação completa.

## Infra
- [ ] `config.js` contém somente Supabase URL + Publishable Key.
- [ ] Nenhuma Secret Key / `service_role` está no repositório.
- [ ] Confirmar que R2 aparece como “ainda não conectado”, sem números fictícios de armazenamento.
