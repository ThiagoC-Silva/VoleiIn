# T07.6 — Rodada completa e correção das mensagens

**Estado:** a fazer · **Depende de:** T07.5

## Objetivo

Rodar o script inteiro de uma vez e levar ao app o que ele mostrou: o `_traduzir` de `app/lib/dados/auth_repositorio.dart` foi escrito com códigos que ninguém tinha visto chegar.

## O que já existe

- O script completo (T07.2 a T07.5), com os `error_code` reais anotados no "Resultado" de cada task.
- `_traduzir` com `invalid_credentials`, `weak_password`, `user_already_exists`, `same_password`, `over_email_send_rate_limit`, `over_request_rate_limit`, `otp_expired`, `email_exists`, `email_address_invalid`/`validation_failed`; o resto cai em "Não foi possível concluir agora".

## O que falta

- [ ] Rodada inteira com `--com-expiracao`, de banco recém-resetado (`supabase db reset`), contando os e-mails gastos e o tempo total.
- [ ] Conferir se `docker restart supabase_auth_VoleiIn` zera o contador de `email_sent`. Se não zerar, registrar a espera de uma hora como único contorno.
- [ ] Cruzar cada `error_code` observado com o `_traduzir`:
  - código que chega e cai no genérico → ganha mensagem;
  - código previsto que nunca aparece (por exemplo, se o local nunca esconde a conta com usuário sem `identities`) → fica, porque o remoto pode usá-lo, mas isso vai para a T09 conferir;
  - código errado e código usado, se chegarem como `otp_expired`, já caem em "Código inválido ou vencido".
- [ ] Um commit por correção, com o teste de widget correspondente quando a correção muda texto de tela.
- [ ] `flutter test` e `dart analyze` passam depois das correções; as três suítes SQL continuam passando.

## Resultado

_Preenchido na execução: tempo da rodada, e-mails gastos, se o reinício zera o limite, e a lista de correções._

## Pronto quando

A rodada inteira termina em `SUCESSO`, e nenhum `error_code` observado cai na mensagem genérica sem motivo registrado.

## Commit

Um por correção, por exemplo `Traduz o código <x> da autenticação`. Sem correção, sem commit.
