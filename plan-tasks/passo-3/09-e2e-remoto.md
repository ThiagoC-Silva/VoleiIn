# T09 — Validação ponta a ponta no remoto

**Estado:** feito · **Depende de:** T08, T13

Execução quebrada em tasks, uma por vez, em `plan-tasks/planT09/`. **Essa pasta será removida**, como as da T07 e da T08, porque o que ela guarda está consolidado neste arquivo e na [T10](10-fechamento.md). As referências a T09.1 a T09.9 abaixo passam então a apontar para tasks que só existem no histórico do git.

## Objetivo

Repetir no projeto remoto, com e-mail real e aparelho físico, o que só aparece fora do ambiente local: entrega do e-mail, filtro de spam e o APK release.

## Da T08

- **Ref:** `zmokpmovphikmobynssy`. **URL:** `https://zmokpmovphikmobynssy.supabase.co`.
- **Chave pública:** `supabase projects api-keys --project-ref zmokpmovphikmobynssy`, a de tipo `publishable` (`sb_publishable_…`).
- **`skip_nonce_check = true` no remoto**, igual ao local (T08.6). Conferir no celular que a entrada pelo Google passa; se o serviço recusar o token, a decisão volta.
- **O Gmail secundário do Thiago com `+t087` já tem conta confirmada no remoto** (T08.7). Não usar nos cenários; os dois Gmails sem sufixo seguem sem conta.
- **DMARC em `p=reject`.** E-mail que falhar na autenticação não cai no spam: é recusado e não chega. Se um código não chegar, olhar os registros do Resend antes da caixa.
- O teto de 30 por hora já teve três envios gastos às 14:58, 15:11 e 16:01 de 2026-10-27.

## O que falta

- [x] Gerar o APK apontando para o remoto e instalar num celular físico:

  ```
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave pública> \
    --dart-define=GOOGLE_WEB_CLIENT_ID=<id do cliente web>
  ```

  Isso confirma a permissão `INTERNET` da T04. O APK assina com a chave de debug da máquina que o gerou, cujo SHA-1 já está no cliente Android (T11).
- [x] Repetir da T07, com dois e-mails reais (um Gmail e outro provedor):
  - cadastro (1);
  - entrada com senha (2);
  - senha errada (3);
  - cadastro com e-mail que já tem conta (5): anotar se o remoto responde `user_already_exists`, como o local, ou um usuário sem `identities`;
  - redefinição de senha com segunda sessão (9);
  - troca de e-mail (13 e 16);
  - Google no primeiro acesso (17);
  - Google em conta com senha (18).
  - cadastro refeito antes do código, com outra senha e outro nome (6, corrigido na T13): valem os do último pedido.
- [x] O que o local não respondeu e o remoto pode responder diferente (T07):
  - cadastro com e-mail que já tem conta (5): no local, `user_already_exists`. O `_traduzir` também cobre o usuário sem `identities`, que nunca apareceu;
  - e-mail inválido: no local, 400 `validation_failed`. O `_traduzir` também cobre `email_address_invalid`, que nunca apareceu;
  - teto de 30 e-mails por hora: no local não há limite (`GOTRUE_RATE_LIMIT_EMAIL_SENT=360000` sem SMTP próprio). A rodada inteira do script gasta 18 e-mails (19 com `--com-expiracao`; contados na T09.2), então cabe uma por hora. Anotar o `error_code` quando o teto for atingido, e se ele chega ao app como "Aguarde um minuto…" ou no genérico;
  - `autenticacao_api.sh` com `MAILPIT_URL` vazio, que pede os códigos no terminal e nunca foi exercitado.
- [x] Para cada e-mail recebido, anotar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn".
- [x] Conferir nos registros do Resend que os envios aparecem entregues, e quanto do teto diário foi gasto.

## Resultado

Feito de 2026-10-27 a 2026-10-28. O Auth remoto é a v2.197.0, a mesma do local na T07. Rodou em dois trilhos:
- **celular:** o APK release (T09.3) num Motorola Edge 60 Pro, operado pelo Claude por `adb`, com os códigos lidos nas notificações do Gmail (T09.4 a T09.6, T09.8);
- **script:** `autenticacao_api.sh --com-expiracao`, sem Mailpit nem `PSQL`, com os códigos digitados pelo Thiago no terminal (T09.7).

**Nenhum cenário divergiu do local, e nenhum código de erro mudou.** O único ponto fora do esperado foi a entrega no Outlook, que vai à T10 como risco.

### APK release

- **54,0 MB** (53.999.223 bytes), contra 107,5 MB do APK de depuração. É o primeiro build release do projeto, e a permissão `INTERNET` da T04 está confirmada.
- **O primeiro release travou na abertura.** O R8 renomeou as classes Kotlin do `shared_preferences_android` 2.5.0, que eram chamadas por JNI e não tinham regra de manutenção. A correção foi subir a dependência transitiva para a 2.5.4 no `pubspec.lock`, que traz o `consumer-rules.pro`, e rodar `flutter clean` (T09.3).
- **O `google_sign_in` passou no release:** o R8 não o afetou, e o SHA-1 desta máquina e o `skip_nonce_check = true` do remoto funcionaram (T09.5).

### Cenários, remoto contra local

| Cenário | Trilho | Remoto | `error_code` no remoto | Contra o local |
| --- | --- | --- | --- | --- |
| 1 cadastro | celular, script | `pessoa` só nasce no código, com o id de `auth.users` e o nome | — | igual |
| 2 entrada com senha | celular, script | entra sem e-mail | — | igual |
| 3 senha errada | celular, script | 400, "E-mail ou senha incorretos.", a A1 fica com os campos | `invalid_credentials` | igual |
| 4 senha de 7 caracteres | script | 422 | `weak_password` | igual |
| 5 e-mail com conta | celular, script | 422, "Esse e-mail já tem conta…", sem e-mail. O remoto **não** esconde a conta com usuário sem `identities` | `user_already_exists` | igual |
| e-mail inválido | script | `carla@`: 400. O `email_address_invalid` não apareceu | `validation_failed` | igual |
| 6 cadastro não confirmado | script | entrada recusada; reenvio antes de 60 s recusado; depois, código novo entra. Pela API, sem o app, vale a senha do **primeiro** pedido | `email_not_confirmed`, `over_email_send_rate_limit`, `invalid_credentials` | igual |
| 6 refeito (T13) | celular, script | pelo app, valem o nome e a senha do último pedido; a senha do impostor é recusada; chega aviso de senha trocada | `invalid_credentials` | igual |
| 7 código errado, repetido e vencido | script | 403 nos três; **o código vence em 300 s** (recusado aos 301 s) | `otp_expired` | igual |
| 8 reenvio antes de 60 s | script | 429 | `over_email_send_rate_limit` | igual |
| 9 redefinição com segunda sessão | celular, script | a outra sessão perde a renovação; a senha antiga é recusada, a nova entra | `refresh_token_not_found`, `invalid_credentials` | igual; `dispositivo_push` não conferido (sem `PSQL`, e o app ainda não registra aparelho) |
| 10 redefinição sem conta | script | 200, corpo igual ao de e-mail com conta, nada enviado | — | igual |
| 11 senha nova igual | script | 422; a sessão do código fica de pé | `same_password` | igual |
| 12 sessão envelhecida | script | só o caminho do app (código, sessão nova, `PUT /user` 200) | — | `reauthentication_needed` não conferido (sem `PSQL`) |
| 13 troca de e-mail | celular, script | código só no endereço novo, aviso no antigo, outras sessões caem | `refresh_token_not_found`, `invalid_credentials` | igual |
| 14 troca sem `logout` | script | a troca sozinha não derruba a outra sessão; o `logout?scope=others` derruba | `refresh_token_not_found` | igual |
| 15 push na troca | script | pulado (sem `PSQL`) | — | não conferido no remoto |
| 16 e-mail de outra conta | celular, script | 422, "Esse e-mail já pertence a outra conta.", sem e-mail | `email_exists` | igual |
| 17 Google, primeiro acesso | celular | `pessoa` com o nome do Google, `avatar_url` nulo, sem senha; sem tela de consentimento, já dada no local | — | igual |
| 18 Google em conta com senha | celular | mesmo `pessoa.id`, o nome do cadastro fica; a senha continua entrando | — | igual |
| teto por hora (T09.8) | celular, `curl` | 429 no quarto envio com o teto em 3 | `over_email_send_rate_limit` | no local não há teto |

A rodada do script: `SUCESSO: 18 cenários`, 21 conferências puladas (as de aviso, de "nenhum e-mail" e de modelos, sem Mailpit; as de banco, sem `PSQL`). A caixa cobriu o que o script pulou: chegaram os 19 e-mails esperados, todos na caixa de entrada, e nenhum a mais, o que confirma também os "nenhum e-mail" (T09.7).

### E-mails do celular

Todos com o remetente "VoleiIn" `<nao-responda@mail.voleiin.com.br>`. O pedido é a hora do Auth; a chegada, a da notificação ou do cabeçalho, em UTC (o Outlook só mostra o minuto).

| E-mail | Para | Pedido | Chegada | Pasta |
| --- | --- | --- | --- | --- |
| "Confirme seu cadastro no VoleiIn" | Gmail | 22:58:57 de 27/10 | 22:59:03 (6 s) | entrada |
| "Seu código para redefinir a senha do VoleiIn" | Gmail | 23:03:05 | 23:03:08 (3 s) | entrada |
| "A senha da sua conta no VoleiIn foi trocada" | Gmail | 23:03:55 | 23:03 | entrada, sem notificação |
| "Confirme seu cadastro no VoleiIn" (impostor) | Outlook digitado errado | 00:13:40 de 28/10 | — | *bounced* |
| "Confirme seu cadastro no VoleiIn" (A2) | Outlook digitado errado | 00:14:46 | — | *suppressed*, não enviado |
| "Confirme seu cadastro no VoleiIn" (impostor) | Outlook | 00:24:32 | 00:24 | Lixo Eletrônico |
| "Confirme seu cadastro no VoleiIn" (A2) | Outlook | 00:25:41 | 00:25 | Lixo Eletrônico |
| "A senha da sua conta no VoleiIn foi trocada" | Outlook | 00:28:02 | 00:28:03 (1 s) | Lixo Eletrônico |
| "Confirme a troca de e-mail no VoleiIn" | Gmail com `+t09` | 00:41:52 | 00:41:57 (5 s) | entrada |
| "O e-mail da sua conta no VoleiIn foi trocado" | Outlook | 00:42:20 | 00:42 | Lixo Eletrônico |

- **Gmail:** tudo na caixa de entrada, em até 6 s, inclusive os 19 da rodada do script. Os 3 do teto saíram como *delivered* no Resend, mas não foram conferidos na caixa um a um. O aviso de senha trocada não gerou notificação, só os códigos: é critério do Gmail sobre o que notifica, não de entrega.
- **Outlook:** os quatro no Lixo Eletrônico, com `spf=pass`, `dkim=pass` (`mail.voleiin.com.br` e `amazonses.com`), `dmarc=pass` e `compauth=pass`, e `SCL: 5`. A autenticação e o DNS conferem com a T08: é o filtro de conteúdo e reputação da Microsoft, para um domínio de dois dias e pouco volume. Pela regra da T09, a execução parou, conferiu a configuração e seguiu com o Thiago; vai à T10 como risco.
- **Resend:** 35 envios no mês, 3 da T08.7 e 32 da T09; no dia mais cheio (28/10, em UTC), 29 contra os 100 do plano gratuito. São 33 *delivered*, 1 *bounced*, 1 *suppressed* e nenhum *complained*. O Resend recebeu cada e-mail de 2 a 3 s depois do pedido no Auth e o entregou ao destino em menos de meio segundo.
- **Uma devolução, e não duas.** O endereço do Outlook digitado errado devolveu o primeiro envio, entrou na lista de supressão, e o Resend nem tentou o segundo (T09.9, corrigindo a T09.6).

### Teto e as mensagens do app

O teto de 30 por hora foi baixado a 3 no painel por meia hora, e a mudança valeu na hora (T09.8). O quarto `/signup` deu 429 `over_email_send_rate_limit`, **o mesmo `error_code` do intervalo de 60 s**. Só o `msg` muda: "email rate limit exceeded" no teto, contra "For security purposes, you can only request this after N seconds." nos 60 s.

Por isso o app erra nos dois lugares:
- a A2 e a A3 mostram "Aguarde um minuto antes de pedir outro código.", mas o teto só passa quando a hora vira;
- a A1, na entrada com senha de cadastro pendente, engole a recusa e abre a A3 esperando um código que não vem.

Os cadastros recusados não criam conta. Não deu para saber se o teto conta por janela fixa ou por recarga contínua. O teto voltou a 30 no painel, conferido na tela.

**Decisão do Thiago, em 2026-10-28:** separar pelo `msg`.
- Se o `msg` for o dos 60 s, tudo fica como hoje: a A1 segue engolindo a recusa, porque o código de menos de um minuto vale.
- Qualquer outro `msg` é o teto. A A2 e a A3 mostram **"Muitos códigos enviados agora. Tente de novo em até uma hora."**, e a A1 mostra a mesma mensagem e não abre a A3.
- Custo aceito: a separação depende de um texto em inglês do Supabase Auth.

A correção não entrou na T09: o texto entra nos documentos antes do código (T10, "Aberto").

### Limpeza

No fim, os 16 usuários de teste saíram do remoto, pela ordem da T07: `dispositivo_push`, depois `pessoa`, depois `auth.users`. Eram o `+t087` da T08.7, os 2 Gmails e as 2 contas do Outlook do celular, as 8 da rodada do script e os 3 do teto. O SQL foi preparado pelo Claude e rodado pelo Thiago no editor do painel. Pelo MCP, `auth.users`, `identities`, `sessions`, `refresh_tokens`, `one_time_tokens`, `pessoa` e `dispositivo_push` estão vazias, assim como as outras oito tabelas que apontam para `pessoa`.

## Pronto quando

Funcionam no celular físico, com e-mail real:
- criar conta, entrar com senha e entrar pelo Google;
- redefinir a senha;
- trocar o e-mail.

O código chega na caixa de entrada em menos de um minuto. Se cair no spam, voltar à configuração de domínio da T08 antes de fechar.

## Commit

Sem commit próprio.
