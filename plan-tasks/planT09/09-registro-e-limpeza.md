# T09.9 — Resend, limpeza e fechamento da T09

**Estado:** feito · **Depende de:** T09.8

## Objetivo

Conferir as entregas no Resend, tirar as contas de teste do remoto e consolidar o resultado na [T09](../passo-3/09-e2e-remoto.md), pronto para a T10.

## O que já existe

- O SQL de exclusão da T07 ("Contas Google" em [`07-e2e-local.md`](../passo-3/07-e2e-local.md)): `dispositivo_push`, depois `pessoa`, depois `auth.users`. `pessoa` não some sozinha, e isso é deliberado.
- Os resultados da T09.1 à T09.8.
- Da T09.6: dois *bounced* esperados no Resend (00:13:40 e 00:14:46 UTC de 2026-10-28, endereço do Outlook digitado errado, hoje na lista de supressão) e o cadastro pendente que eles deixaram (id `9abdf4bf…`, sem `pessoa`), que entra na limpeza. E o Outlook mandando os quatro e-mails ao Lixo Eletrônico com SPF, DKIM e DMARC aprovados, que vai à T10 como risco.

- Da T09.7: as contas da rodada, todas `+<nome>.1793196422547` no Gmail 2. Carla (hoje no endereço da `+carla2`), Eva, Eva2, Helena, Fábio, Bruno e Gil confirmadas, e Heitor pendente. A tabela de cenários remoto contra local está no Resultado dela.

- Da T09.8: três cadastros pendentes no remoto, `+teto1`, `+teto2` e `+teto3` com `.1793202703` no Gmail 2. E a decisão do Thiago sobre as mensagens do teto (separar pelo `msg` da recusa, com "Muitos códigos enviados agora. Tente de novo em até uma hora."), que vai à T10 como correção a fazer: o texto entra nos documentos antes do código.

## O que falta

- [x] **[Thiago]** No Resend: os envios do dia aparecem como "Delivered", sem "Bounced" nem "Complained"; quanto do dia e do mês foi gasto.
- [x] Pelo MCP, só leitura, a lista de usuários do remoto, com o id e se tem `pessoa`, para montar o SQL de limpeza.
- [x] **[Thiago]** No editor SQL do painel, o SQL que o Claude preparar, apagando todas as contas de teste, inclusive a `+t087` da T08.7.
- [x] Pelo MCP: `auth.users`, `pessoa` e `dispositivo_push` vazias no remoto.
- [x] [`09-e2e-remoto.md`](../passo-3/09-e2e-remoto.md): caixas marcadas, estado "feito" e um "Resultado" com:
  - a tabela de cenários, remoto contra local, com o `error_code` de cada um;
  - a tabela dos e-mails do celular: pedido, chegada, pasta, remetente;
  - o teto e as mensagens do app;
  - a nota de que a pasta `plan-tasks/planT09/` será removida e fica no histórico, como as da T07 e da T08.
- [x] [README do passo 3](../passo-3/README.md): T09 → feito.
- [x] [T10](../passo-3/10-fechamento.md): o que a T09 acrescenta às decisões e ao "Aberto". Em "Aberto", trocar a linha da conta `+t087` pelo remoto sem usuário, e incluir o que a T09.8 levar como decisão. Se ainda houver decisão de produto aberta, a T10 não começa antes de ela fechar.

## Resultado

Feito em 2026-10-28.

- **Resend**, pelo `emails-sent.csv` exportado pelo Thiago: 35 envios no mês, 3 da T08.7 e 32 da T09; 29 no dia 28/10 (em UTC), contra os 100 do plano gratuito. São 33 *delivered*, 1 *bounced*, 1 *suppressed* e nenhum *complained*. Todos saíram com o remetente "VoleiIn" `<nao-responda@mail.voleiin.com.br>`. O Resend recebeu cada e-mail de 2 a 3 s depois do pedido no Auth e o entregou ao destino em menos de meio segundo.
- **Uma devolução, e não duas, como a T09.6 anotou.** O primeiro envio ao Outlook digitado errado (00:13:44) voltou como *bounced* e pôs o endereço na lista de supressão; o segundo (00:14:48) saiu como *suppressed*, sem tentativa de envio. Corrigido na T09.6 e no README.
- **Antes da limpeza**, pelo MCP: 16 usuários, todos de teste (o `+t087`, os dois Gmails e as duas contas do Outlook do celular, as oito da rodada do script e os três do teto), 11 com `pessoa` e 5 pendentes sem ela. Nenhuma `pessoa` órfã, nenhum `dispositivo_push`, e as outras oito tabelas que apontam para `pessoa` (`jogo`, `cobranca`, `grupo`…) vazias.
- **Limpeza:** o SQL apagou pelos 16 ids escritos um a um, numa transação, na ordem da T07 (`dispositivo_push`, `pessoa`, `auth.users`), e foi rodado pelo Thiago no editor do painel. O painel avisou de operação destrutiva e de tabela sem política de linha; a tabela era a temporária dos ids, apagada no `commit`, e o Thiago rodou "without RLS". Contagem no fim: `0, 0, 0, 0`.
- **Depois, pelo MCP:** `auth.users`, `identities`, `sessions`, `refresh_tokens`, `one_time_tokens`, `pessoa` e `dispositivo_push` com zero linhas.
- **Teto:** em 30 desde a T09.8, conferido pelo Thiago na tela do painel às 16:23 UTC. O MCP não lê a configuração do Auth.
- **[T09](../passo-3/09-e2e-remoto.md):** feita, com o "Resultado" consolidado e a nota da pasta `planT09/`. **[T10](../passo-3/10-fechamento.md):** cinco decisões e cinco itens de "Aberto" novos; a linha do `+t087` virou o remoto sem usuário. Não há decisão de produto aberta: a do teto está tomada, e falta só a correção, com o texto antes do código.
- **Fora do commit:** o `emails-sent.csv` e o `Imagem colada.png` da raiz, que trazem os endereços do Thiago.

## Pronto quando

A T09 está feita, com o resultado consolidado no arquivo dela, o remoto sem contas de teste e o teto em 30.

## Commit

`Fecha a validação ponta a ponta no remoto`
