# T09 — Validação ponta a ponta no remoto

**Estado:** a fazer · **Depende de:** T08, T13

## Objetivo

Repetir no projeto remoto, com e-mail real e aparelho físico, o que só aparece fora do ambiente local: entrega do e-mail, filtro de spam e o APK release.

## O que falta

- [ ] Gerar o APK apontando para o remoto e instalar num celular físico:

  ```
  flutter build apk --release \
    --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
    --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave pública> \
    --dart-define=GOOGLE_WEB_CLIENT_ID=<id do cliente web>
  ```

  Isso confirma a permissão `INTERNET` da T04. O APK assina com a chave de debug da máquina que o gerou, cujo SHA-1 já está no cliente Android (T11).
- [ ] Repetir da T07, com dois e-mails reais (um Gmail e outro provedor):
  - cadastro (1);
  - entrada com senha (2);
  - senha errada (3);
  - cadastro com e-mail que já tem conta (5): anotar se o remoto responde `user_already_exists`, como o local, ou um usuário sem `identities`;
  - redefinição de senha com segunda sessão (9);
  - troca de e-mail (13 e 16);
  - Google no primeiro acesso (17);
  - Google em conta com senha (18).
  - cadastro refeito antes do código, com outra senha e outro nome (6, corrigido na T13): valem os do último pedido.
- [ ] O que o local não respondeu e o remoto pode responder diferente (T07):
  - cadastro com e-mail que já tem conta (5): no local, `user_already_exists`. O `_traduzir` também cobre o usuário sem `identities`, que nunca apareceu;
  - e-mail inválido: no local, 400 `validation_failed`. O `_traduzir` também cobre `email_address_invalid`, que nunca apareceu;
  - teto de 30 e-mails por hora: no local não há limite (`GOTRUE_RATE_LIMIT_EMAIL_SENT=360000` sem SMTP próprio). A rodada inteira do script gasta 16 e-mails, então cabe uma por hora. Anotar o `error_code` quando o teto for atingido, e se ele chega ao app como "Aguarde um minuto…" ou no genérico;
  - `autenticacao_api.sh` com `MAILPIT_URL` vazio, que pede os códigos no terminal e nunca foi exercitado.
- [ ] Para cada e-mail recebido, anotar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn".
- [ ] Conferir nos registros do Resend que os envios aparecem entregues, e quanto do teto diário foi gasto.

## Pronto quando

Funcionam no celular físico, com e-mail real:
- criar conta, entrar com senha e entrar pelo Google;
- redefinir a senha;
- trocar o e-mail.

O código chega na caixa de entrada em menos de um minuto. Se cair no spam, voltar à configuração de domínio da T08 antes de fechar.

## Commit

Sem commit próprio.
