# T09.8 — Teto de e-mails por hora

**Estado:** a fazer · **Depende de:** T09.7

## Objetivo

Ver o que o remoto devolve quando o teto de e-mails por hora é atingido, e o que o app mostra. No local não há teto (T07), e o `_traduzir` só supõe.

## O que já existe

- O teto é 30 por hora e mora só no painel: Authentication → Rate Limits (T08.6).
- No app, `over_email_send_rate_limit` vira "Aguarde um minuto antes de pedir outro código.", que é a mensagem dos 60 s entre envios. `over_request_rate_limit` vira "Muitas tentativas seguidas. Aguarde alguns minutos.".
- A T09.7 mandou 19 e-mails das 14:07 às 14:22 UTC de 2026-10-28, sem recusa. Para a contagem do teto baixado começar do zero, a T09.8 começa a partir de 15:23 UTC (12:23 em Brasília), uma hora depois do último deles, como a T09.7 fez com a T09.6.
- Na entrada com senha de cadastro pendente, a A1 reenvia o código e **engole** `over_email_send_rate_limit`, porque nos 60 s o código anterior ainda vale (T07, cenário 6).

## O que falta

- [ ] **[Thiago]** No painel, baixar o teto para 3 por hora. Anotar a hora.
- [ ] Por `curl`, `/signup` a endereços novos com `+` no Gmail 2, um depois do outro, até a recusa. Anotar quantos passaram, o status e o `error_code` da recusa. Se o teto não chegar em seis pedidos, parar e anotar: a troca pode não valer na hora.
- [ ] Com o teto atingido, **[Thiago]** no celular:
  - A2 com um endereço novo com `+`: anotar a mensagem;
  - A1 com o endereço do primeiro `/signup` acima, ainda pendente, e a senha dele: anotar se a A3 abre esperando um código que não vem.
- [ ] **[Thiago]** No painel, o teto de volta a 30. Conferir na tela que ficou 30.
- [ ] Se o código da recusa for `over_email_send_rate_limit`, as duas mensagens erram: "Aguarde um minuto" promete o que não acontece, e a A1 cala. **Não corrigir aqui:** registrar no Resultado e levar ao Thiago como decisão, com o texto proposto.

## Resultado

## Pronto quando

O código da recusa do teto e o que as duas telas mostram estão anotados, e o teto está de volta a 30 no painel.

## Commit

`Registra o teto de e-mails no remoto`
