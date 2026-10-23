# T07.6 — Rodada completa e correção das mensagens

**Estado:** feito · **Depende de:** T07.5

## Objetivo

Rodar o script inteiro de uma vez e levar ao app o que ele mostrou: o `_traduzir` de `app/lib/dados/auth_repositorio.dart` foi escrito com códigos que ninguém tinha visto chegar.

## O que já existe

- O script completo (T07.2 a T07.5), com os `error_code` reais anotados no "Resultado" de cada task.
- `_traduzir` com `invalid_credentials`, `weak_password`, `user_already_exists`, `same_password`, `over_email_send_rate_limit`, `over_request_rate_limit`, `otp_expired`, `email_exists`, `email_address_invalid`/`validation_failed`; o resto cai em "Não foi possível concluir agora".

## O que falta

- [x] Rodada inteira com `--com-expiracao`, de banco recém-resetado (`supabase db reset`), contando os e-mails gastos e o tempo total.
- [x] Conferir se `docker restart supabase_auth_VoleiIn` zera o contador de `email_sent`. Se não zerar, registrar a espera de uma hora como único contorno.
- [x] Cruzar cada `error_code` observado com o `_traduzir`:
  - código que chega e cai no genérico → ganha mensagem;
  - código previsto que nunca aparece (por exemplo, se o local nunca esconde a conta com usuário sem `identities`) → fica, porque o remoto pode usá-lo, mas isso vai para a T09 conferir;
  - código errado e código usado, se chegarem como `otp_expired`, já caem em "Código inválido ou vencido".
- [x] Um commit por correção, com o teste de widget correspondente quando a correção muda texto de tela.
- [x] `flutter test` e `dart analyze` passam depois das correções; as três suítes SQL continuam passando.

## Resultado

Rodada contra o local em 2026-10-23, Auth v2.197.0, logo depois de `supabase db reset`:

- `autenticacao_api.sh --com-expiracao`: `SUCESSO: 17 cenários`, modelos 5 de 5, em **6 min 45 s** (301 s na espera do código vencido, o resto quase todo nas esperas de 61 s e de `sem_email`). **16 e-mails** contados no Mailpit.
- **Não há limite de e-mails no local**, e por isso não há contador a zerar. `email_sent = 30` exige SMTP próprio; sem ele, o CLI sobe o Auth com `GOTRUE_RATE_LIMIT_EMAIL_SENT=360000` (`docker inspect`), como a T03 já tinha anotado em `02-config-auth-local.md`. Conferido: com 13 e-mails na última hora, mais 25 cadastros seguidos foram aceitos e chegaram todos. A premissa da T07.1 estava errada; `07-e2e-local.md` (Limites do Auth local) e o README foram corrigidos. O teto de 30 por hora só se verifica no remoto, na T09.
- `supabase db reset` reinicia também o contêiner do Auth, e com ele os limites por IP, que são guardados em memória.
- Suítes SQL: schema 61, rls 69, autenticacao 36. `dart analyze` sem problemas; `flutter test` com 24 testes.

Códigos observados, cruzados com o `_traduzir`:

| `error_code` | Onde chega | No app |
| --- | --- | --- |
| `invalid_credentials` | 3, 6, 9 | "E-mail ou senha incorretos." |
| `weak_password` | 4 | mensagem da senha curta |
| `user_already_exists` | 5 | "Esse e-mail já tem conta…" |
| `validation_failed` | e-mail inválido | "Confira o e-mail digitado." |
| `email_not_confirmed` | 6 | não passa pelo `_traduzir`: o `entrar` reenvia o código e segue para a A3 |
| `over_email_send_rate_limit` | 6, 8 | "Aguarde um minuto…"; no `entrar`, engolido de propósito |
| `otp_expired` | 7 (errado, repetido e vencido) | "Código inválido ou vencido…" |
| `same_password` | 11 | "A senha nova precisa ser diferente da atual." |
| `email_exists` | 16 | "Esse e-mail já pertence a outra conta." |
| `refresh_token_not_found` | 9, 13, 14 | não passa pelo `_traduzir`: é a renovação automática do SDK, que encerra a sessão |
| `reauthentication_needed` | 12 | cairia no genérico, mas o app nunca chega a ele: o `redefinirSenha` sempre confere o código antes, e a sessão nasce nova (é o que justifica não haver tela de reautenticação) |

- **Nenhuma correção**: nenhum código observado cai no genérico sem motivo registrado. Sem correção, sem commit.
- Previstos e nunca vistos no local, mantidos para a T09 conferir no remoto: `email_address_invalid` (o local mandou `validation_failed`), `over_request_rate_limit` (não exercitado, ver `07-e2e-local.md`) e o usuário sem `identities` no cadastro repetido (o local mandou `user_already_exists`).
- **Continuam abertos, sem `error_code` a traduzir**, para conferir no celular na T07.8:
  - cenário 6, segundo cadastro pendente com outra senha: depois de 60 s, a API responde como sucesso e manda código novo, mas só a primeira senha entra e o nome fica o do primeiro cadastro. A mensagem não tem como avisar, porque a resposta é igual à de um cadastro novo; se pede mudança, é decisão de produto;
  - cenário 11, mesma senha na redefinição: a sessão nasce no `verifyOTP` e continua de pé depois do `same_password`, e a rota pode levar ao início antes de a mensagem aparecer.

## Pronto quando

A rodada inteira termina em `SUCESSO`, e nenhum `error_code` observado cai na mensagem genérica sem motivo registrado.

## Commit

Um por correção, por exemplo `Traduz o código <x> da autenticação`. Não houve correção; o registro foi junto com o da T07.7.
