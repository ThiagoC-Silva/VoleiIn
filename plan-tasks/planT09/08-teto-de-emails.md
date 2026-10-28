# T09.8 — Teto de e-mails por hora

**Estado:** feito · **Depende de:** T09.7

## Objetivo

Ver o que o remoto devolve quando o teto de e-mails por hora é atingido, e o que o app mostra. No local não há teto (T07), e o `_traduzir` só supõe.

## O que já existe

- O teto é 30 por hora e mora só no painel: Authentication → Rate Limits (T08.6).
- No app, `over_email_send_rate_limit` vira "Aguarde um minuto antes de pedir outro código.", que é a mensagem dos 60 s entre envios. `over_request_rate_limit` vira "Muitas tentativas seguidas. Aguarde alguns minutos.".
- A T09.7 mandou 19 e-mails das 14:07 às 14:22 UTC de 2026-10-28, sem recusa. Para a contagem do teto baixado começar do zero, a T09.8 começa a partir de 15:23 UTC (12:23 em Brasília), uma hora depois do último deles, como a T09.7 fez com a T09.6.
- Na entrada com senha de cadastro pendente, a A1 reenvia o código e **engole** `over_email_send_rate_limit`, porque nos 60 s o código anterior ainda vale (T07, cenário 6).

## O que falta

- [x] **[Thiago]** No painel, baixar o teto para 3 por hora. Anotar a hora.
- [x] Por `curl`, `/signup` a endereços novos com `+` no Gmail 2, um depois do outro, até a recusa. Anotar quantos passaram, o status e o `error_code` da recusa. Se o teto não chegar em seis pedidos, parar e anotar: a troca pode não valer na hora.
- [x] Com o teto atingido, **[Thiago]** no celular:
  - A2 com um endereço novo com `+`: anotar a mensagem;
  - A1 com o endereço do primeiro `/signup` acima, ainda pendente, e a senha dele: anotar se a A3 abre esperando um código que não vem.
- [x] **[Thiago]** No painel, o teto de volta a 30. Conferir na tela que ficou 30.
- [x] Se o código da recusa for `over_email_send_rate_limit`, as duas mensagens erram: "Aguarde um minuto" promete o que não acontece, e a A1 cala. **Não corrigir aqui:** registrar no Resultado e levar ao Thiago como decisão, com o texto proposto.

## Resultado

Feito em 2026-10-28, das 15:51 às 16:23 UTC (12:51 às 13:23 em Brasília), 89 min depois do último e-mail da T09.7. O Claude operou o celular pelo `adb`, no APK release da T09.3, e o Thiago mexeu no painel.

| Quando (UTC) | O quê | Resultado |
| --- | --- | --- |
| 15:51 | **[Thiago]** Teto de 30 para 3 no painel | valeu na hora, sem espera |
| 15:51:43, :45, :48 | `/signup` a `+teto1`, `+teto2` e `+teto3` no Gmail 2 | 200 nos três. O Gmail do celular notificou "Confirme seu cadastro no VoleiIn" às 15:51:52; a caixa não foi conferida endereço a endereço |
| 15:51:50 | `/signup` a `+teto4` | 429 `over_email_send_rate_limit`, `msg` "email rate limit exceeded" |
| 15:54:21 | A2 com `+tetoa2` | "Aguarde um minuto antes de pedir outro código.", e a tela fica na A2 |
| 15:56:53 | A1 com `+teto1` e a senha dele, 10 s depois de o código de 15:51:43 vencer | a A3 abre com "Enviamos um código de 6 dígitos para … Ele vale por 5 minutos.", e nada é enviado: o reenvio foi recusado e engolido |
| 15:58:00 | "Reenviar código" na A3, ao fim dos 60 s | "Aguarde um minuto antes de pedir outro código.", e o contador volta a 60 s |
| 16:23 | **[Thiago]** Teto de volta a 30 no painel, conferido na tela | 30 |

- **A recusa do teto tem o mesmo `error_code` do intervalo de 60 s.** Só o `msg` muda: "email rate limit exceeded" no teto, e "For security purposes, you can only request this after 59 seconds." nos 60 s (sondado no local, v2.197.0, por um `/resend` logo depois do `/signup`). Por isso as duas mensagens erram, como a task previa: "Aguarde um minuto" promete o que não acontece, porque o teto dura até a hora virar, e a A1 cala e manda a pessoa a uma A3 que espera um código que não vem.
- **Os cadastros recusados não criam conta:** depois da recusa, a entrada com senha dá `invalid_credentials` no `+teto4` e no `+tetoa2`, e `email_not_confirmed` no `+teto1`. Ficam no remoto só os três pendentes (`+teto1`, `+teto2`, `+teto3`, com o sufixo `.1793202703`), para a T09.9.
- **Janela fixa ou recarga contínua:** não deu para saber. Os três envios passaram 89 min depois da rodada da T09.7, o que vale nos dois modelos, e o teto voltou a 30 antes de uma hora.
- **Gastos:** 3 envios. No dia (UTC), 29 contra 100 do Resend.
- **Folha "Salvar senha" do Google** depois da A2, embora o cadastro tenha sido recusado. Fechada com "voltar".
- **Bateria do celular em 7%** no começo: a operação esperou o Thiago pôr o aparelho para carregar.

### Decisão do Thiago: separar pelo texto

Tomada em 2026-10-28, entre três opções: separar pelo texto; um texto único, com a A1 engolindo a recusa como hoje; e um texto único, sem a exceção da A1. **Não corrigido aqui:** o código muda em outra rodada, depois de o texto entrar nos documentos.

- O app distingue a recusa pelo `msg` do `over_email_send_rate_limit`. Se ele for o dos 60 s ("…after N seconds"), fica tudo como hoje: "Aguarde um minuto antes de pedir outro código." na A2 e na A3, e a A1 engole a recusa e segue para a A3, porque o código de menos de um minuto vale.
- Qualquer outro `msg` é o teto. A A2 e a A3 mostram **"Muitos códigos enviados agora. Tente de novo em até uma hora."**, e a A1 mostra a mesma mensagem e não abre a A3.
- Ficou de fora o texto único com a A1 sem exceção. Ele quebraria o caso comum de quem se cadastra, perde o app ao abrir o Gmail e entra pela A1 em menos de um minuto: essa pessoa ficaria presa na A1 com um código válido na caixa.
- **Custo aceito:** depende de um texto em inglês do Supabase Auth. Se o texto dos 60 s mudar, o caso dos 60 s passa a mostrar a mensagem do teto e a A1 para nele, o que é errado, mas não é silencioso.

## Pronto quando

O código da recusa do teto e o que as duas telas mostram estão anotados, e o teto está de volta a 30 no painel.

## Commit

`Registra o teto de e-mails no remoto`
