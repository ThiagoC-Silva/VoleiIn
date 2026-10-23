# T07.3 — Script: confirmação, códigos e reenvio (cenários 6 a 8)

**Estado:** a fazer · **Depende de:** T07.2

## Objetivo

Cobrir o cadastro pendente e as recusas de código: o que o `entrar` do app trata como "volta para a A3" e o que o `_traduzir` mostra para código errado, vencido ou repetido.

## O que já existe

As funções de apoio e os cenários 1 a 5 da T07.2.

## O que falta

- [ ] **Cenário 6** — Eva:
  - `/signup` e nenhuma confirmação;
  - `/token?grant_type=password` dá `email_not_confirmed`;
  - `/resend` (`type: signup`) logo depois dá `over_email_send_rate_limit` (é o caso que o `entrar` do app engole);
  - esperar 61 s, `/resend` de novo, chega o código; `/verify` entra;
  - **anotar**: um segundo `/signup` com outra senha antes de confirmar (usar uma segunda pessoa, `eva2`, para não misturar). Responde como? Envia código? Depois de confirmar, qual senha entra?
- [ ] **Cenário 7** — Fábio, cadastro pendente:
  - código errado (`000000`, ou um que não seja o enviado) é recusado;
  - o código certo entra;
  - o mesmo código de novo é recusado;
  - **anotar** o `error_code` de cada recusa (é provável que as duas venham como `otp_expired`).
  - Com `--com-expiracao`: outra pessoa, esperar 301 s depois do envio, e o código é recusado; anotar o `error_code`.
- [ ] **Cenário 8** — `/resend` do Fábio antes de 60 s do cadastro: `over_email_send_rate_limit`, com status 429. Rodar antes da confirmação do cenário 7.
- [ ] Contar os e-mails desta parte e conferir que a rodada inteira continua dentro de 30 por hora.

## Resultado

_Preenchido na execução: os `error_code` do 7 e o comportamento do segundo cadastro no 6._

## Pronto quando

`autenticacao_api.sh --so 6,7,8` passa, e `--com-expiracao --so 7` também.

## Commit

`Cobre a confirmação do cadastro no roteiro da API`
