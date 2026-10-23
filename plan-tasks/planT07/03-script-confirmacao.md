# T07.3 — Script: confirmação, códigos e reenvio (cenários 6 a 8)

**Estado:** feito · **Depende de:** T07.2

## Objetivo

Cobrir o cadastro pendente e as recusas de código: o que o `entrar` do app trata como "volta para a A3" e o que o `_traduzir` mostra para código errado, vencido ou repetido.

## O que já existe

As funções de apoio e os cenários 1 a 5 da T07.2.

## O que falta

- [x] **Cenário 6** — Eva:
  - `/signup` e nenhuma confirmação;
  - `/token?grant_type=password` dá `email_not_confirmed`;
  - `/resend` (`type: signup`) logo depois dá `over_email_send_rate_limit` (é o caso que o `entrar` do app engole);
  - esperar 61 s, `/resend` de novo, chega o código; `/verify` entra;
  - **anotar**: um segundo `/signup` com outra senha antes de confirmar (usar uma segunda pessoa, `eva2`, para não misturar). Responde como? Envia código? Depois de confirmar, qual senha entra?
- [x] **Cenário 7** — Fábio, cadastro pendente:
  - código errado (`000000`, ou um que não seja o enviado) é recusado;
  - o código certo entra;
  - o mesmo código de novo é recusado;
  - **anotar** o `error_code` de cada recusa (é provável que as duas venham como `otp_expired`).
  - Com `--com-expiracao`: outra pessoa, esperar 301 s depois do envio, e o código é recusado; anotar o `error_code`.
- [x] **Cenário 8** — `/resend` do Fábio antes de 60 s do cadastro: `over_email_send_rate_limit`, com status 429. Rodar antes da confirmação do cenário 7.
- [x] Contar os e-mails desta parte e conferir que a rodada inteira continua dentro de 30 por hora.

## Resultado

Rodada contra o local em 2026-10-23, Auth v2.197.0:

| Cenário | Observado |
| --- | --- |
| 6 | Entrada sem confirmar: 400 `email_not_confirmed`. `/resend` logo depois: 429 `over_email_send_rate_limit`. Depois de 61 s do cadastro, `/resend` 200, chega o código novo, `/verify` 200 com sessão do mesmo usuário |
| 6, segundo cadastro (eva2) | Antes de 60 s: 429 `over_email_send_rate_limit`, nenhum código. Depois de 60 s: 200, mesmo id, **código novo enviado**. Confirmada pelo código mais novo, entra **só a primeira senha**; a segunda e a terceira dão `invalid_credentials`. `pessoa.nome` fica com o nome do **primeiro** cadastro |
| 7 | Código errado: 403 `otp_expired`. Código certo: 200 com sessão. O mesmo código de novo: 403 `otp_expired` |
| 7, `--com-expiracao` | Código usado 301 s depois do envio: 403 `otp_expired` |
| 8 | `/resend` do Fábio antes de 60 s: 429 `over_email_send_rate_limit` |

- As três recusas de código chegam como `otp_expired`, e o `_traduzir` já as leva a "Código inválido ou vencido. Confira ou peça outro.".
- **Para a T07.6 e a T07.8**: o segundo cadastro com o mesmo e-mail antes de confirmar não troca senha nem nome, mas, depois de 60 s, responde como sucesso e manda código novo. No app, quem volta da A3 para a A2 e cadastra de novo com outra senha confirma e entra (a sessão vem do `/verify`), mas na próxima entrada a senha que digitou por último dá "E-mail ou senha incorretos.". Antes de 60 s, a A2 mostra "Aguarde um minuto antes de pedir outro código.". Não é decisão desta task; fica registrado para a rodada de correções.
- E-mails: `--so 6,7,8` gasta 5 (Eva 2, eva2 2, Fábio 1) e leva cerca de 67 s, quase todo nas esperas de 61 s, que correm juntas para a Eva e a eva2. `--com-expiracao` soma 1 (Heitor) e 301 s. A rodada inteira até aqui gasta 7, contando a Carla da T07.2, e cabe nos 30 por hora com a estimativa de 13 a 15 da rodada completa. A execução desta task, com as sondas, gastou 15 e-mails na hora.
- O 8 roda antes do 7 (`roda 8` antes de `roda 7`), para o reenvio acontecer antes da confirmação; com `--so 7` ou `--so 8` sozinho, o Fábio é criado do mesmo jeito.

## Pronto quando

`autenticacao_api.sh --so 6,7,8` passa, e `--com-expiracao --so 7` também.

## Commit

`Cobre a confirmação do cadastro no roteiro da API`
