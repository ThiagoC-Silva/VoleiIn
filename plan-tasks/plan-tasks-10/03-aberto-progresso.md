# T10.3 — "Aberto" da entrada

**Estado:** a fazer · **Depende de:** T10.2

## Objetivo

Fechar a entrada do passo 3 em [`docs/progresso.md`](../../docs/progresso.md) com a seção **Aberto**: o que ficou pendente e por quê, para quem abrir o passo 4 não descobrir sozinho.

São doze itens, de três naturezas: dívida que tem passo marcado, risco que fica de pé e coisa que não se sabe. A seção deve deixar claro qual é qual.

## O que já existe

- **Os doze itens enumerados** na [T10](../passo-3/10-fechamento.md), já com a origem de cada um.
- **O "Aberto" dos passos 1 e 2** como medida: linha curta, com o motivo e, quando existe, o passo em que resolve. No passo 2, um item resolvido durante o passo seguinte ficou riscado com `~~…~~` e a resolução em seguida — vale repetir a forma se algum item cair antes de a entrada ser escrita.
- **A tabela de riscos de `docs/stack.md`**, onde cinco desses itens já têm tratamento registrado. O "Aberto" aponta para lá em vez de copiar o tratamento inteiro.

## O que falta

- [ ] Escrever o **Aberto** com os doze itens:
  - o domínio `voleiin.com.br` vence em 26/10/2027, com alerta no Google Agenda; vencido, derruba o login inteiro;
  - o `seed.sql` não foi ao remoto, que está sem locais nem quadras (T08.4);
  - o remoto chega ao passo 4 sem usuário, sem `pessoa` e sem `dispositivo_push`: as contas de teste da T08, da T09 e da T14 foram apagadas;
  - e-mails no Outlook caem no Lixo Eletrônico com SPF, DKIM e DMARC aprovados (`SCL: 5`): é reputação de domínio novo, não configuração (T09.6). Quem usa Outlook pode não achar o código; no Gmail tudo chega na caixa de entrada em até 6 s;
  - no remoto não foram conferidos o `reauthentication_needed` da sessão envelhecida (cenário 12) nem as linhas de `dispositivo_push` (9 e 15), porque o roteiro rodou sem `PSQL`; vieram ao remoto pela mesma migração e pelo mesmo `config.toml` conferidos na T07;
  - não se sabe se o teto de e-mails por hora conta por janela fixa ou por recarga contínua (T09.8);
  - cadastro pendente de impostor concluído pela redefinição de senha nasce com o nome do impostor; a senha que vale é a da dona, e o nome só se troca pela H2 (risco aceito em 2026-10-27; `docs/stack.md`, Riscos);
  - a base clara do design system e a escolha de aparência ficam para o grupo H, que tem o botão de trocar; a troca de e-mail usa as casas do código, mas o resto da H3 não foi aplicado;
  - `flutter analyze` quebra com o caminho "Área de trabalho", e o contorno é o `dart analyze` (link simbólico não resolve);
  - tela de consentimento do Google em teste: só as usuárias de teste entram pelo Google até o passo 10, que a publica com página inicial e Política de Privacidade no GitHub Pages;
  - chave própria de assinatura do APK distribuído, com o SHA-1 dela no cliente Android do Google (passo 10); até lá, o release assina com a chave de debug de quem o gera;
  - `inicio_tela.dart` é provisória, e sair ainda não apaga o aparelho de push (passo 7).
- [ ] Marcar o passo de resolução onde existe: `seed.sql` e locais reais no piloto, aparência no grupo H, nome do perfil na H2, saída que apaga o aparelho no passo 7, consentimento e chave de assinatura no passo 10.
- [ ] Separar o que é **desconhecido** (a contagem do teto) do que é **dívida com prazo**: desconhecido não ganha passo, ganha a frase de que não se sabe.
- [ ] Não repetir em "Aberto" o que já é decisão na T10.2. O teto de e-mails, por exemplo, está **decidido e implementado** (T14): só a contagem por hora continua desconhecida.
- [ ] Decidir o que fazer com um item do **passo 1**, não do 3: o "Aberto" dele diz que os comandos rodam com `sg docker -c` até a sessão ser reaberta, e na T10.1 o `docker` rodou direto. Riscar lá, com `~~…~~`, ou deixar como está — o que não vale é a entrada do passo 3 falar de um item de outro passo.
- [ ] Conferir se algum item já caiu desde que a T10 o listou. Se caiu, riscar com `~~…~~` e dizer onde resolveu, como no passo 2.

## Resultado

## Pronto quando

A entrada do passo 3 está completa pelo modelo: resumo, "Arquivos", "Decisões de implementação" e "Aberto", com os doze itens e, onde cabe, o passo em que cada um resolve.

## Commit

`Registra o que ficou aberto no passo 3`
