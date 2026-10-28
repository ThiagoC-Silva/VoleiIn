# T09.9 — Resend, limpeza e fechamento da T09

**Estado:** a fazer · **Depende de:** T09.8

## Objetivo

Conferir as entregas no Resend, tirar as contas de teste do remoto e consolidar o resultado na [T09](../passo-3/09-e2e-remoto.md), pronto para a T10.

## O que já existe

- O SQL de exclusão da T07 ("Contas Google" em [`07-e2e-local.md`](../passo-3/07-e2e-local.md)): `dispositivo_push`, depois `pessoa`, depois `auth.users`. `pessoa` não some sozinha, e isso é deliberado.
- Os resultados da T09.1 à T09.8.
- Da T09.6: dois *bounced* esperados no Resend (00:13:40 e 00:14:46 UTC de 2026-10-28, endereço do Outlook digitado errado, hoje na lista de supressão) e o cadastro pendente que eles deixaram (id `9abdf4bf…`, sem `pessoa`), que entra na limpeza. E o Outlook mandando os quatro e-mails ao Lixo Eletrônico com SPF, DKIM e DMARC aprovados, que vai à T10 como risco.

- Da T09.7: as contas da rodada, todas `+<nome>.1793196422547` no Gmail 2. Carla (hoje no endereço da `+carla2`), Eva, Eva2, Helena, Fábio, Bruno e Gil confirmadas, e Heitor pendente. A tabela de cenários remoto contra local está no Resultado dela.

## O que falta

- [ ] **[Thiago]** No Resend: os envios do dia aparecem como "Delivered", sem "Bounced" nem "Complained"; quanto do dia e do mês foi gasto.
- [ ] Pelo MCP, só leitura, a lista de usuários do remoto, com o id e se tem `pessoa`, para montar o SQL de limpeza.
- [ ] **[Thiago]** No editor SQL do painel, o SQL que o Claude preparar, apagando todas as contas de teste, inclusive a `+t087` da T08.7.
- [ ] Pelo MCP: `auth.users`, `pessoa` e `dispositivo_push` vazias no remoto.
- [ ] [`09-e2e-remoto.md`](../passo-3/09-e2e-remoto.md): caixas marcadas, estado "feito" e um "Resultado" com:
  - a tabela de cenários, remoto contra local, com o `error_code` de cada um;
  - a tabela dos e-mails do celular: pedido, chegada, pasta, remetente;
  - o teto e as mensagens do app;
  - a nota de que a pasta `plan-tasks/planT09/` será removida e fica no histórico, como as da T07 e da T08.
- [ ] [README do passo 3](../passo-3/README.md): T09 → feito.
- [ ] [T10](../passo-3/10-fechamento.md): o que a T09 acrescenta às decisões e ao "Aberto". Em "Aberto", trocar a linha da conta `+t087` pelo remoto sem usuário, e incluir o que a T09.8 levar como decisão. Se ainda houver decisão de produto aberta, a T10 não começa antes de ela fechar.

## Resultado

## Pronto quando

A T09 está feita, com o resultado consolidado no arquivo dela, o remoto sem contas de teste e o teto em 30.

## Commit

`Fecha a validação ponta a ponta no remoto`
