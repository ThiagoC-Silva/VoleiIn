# T09 — Validação ponta a ponta no remoto

**Estado:** a fazer · **Depende de:** T08

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
- [ ] Para cada e-mail recebido, anotar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn".
- [ ] Conferir no painel do Brevo o contador de envios do dia.

## Pronto quando

Funcionam no celular físico, com e-mail real:
- criar conta, entrar com senha e entrar pelo Google;
- redefinir a senha;
- trocar o e-mail.

O código chega na caixa de entrada em menos de um minuto. Se cair no spam, voltar à configuração de domínio da T08 antes de fechar.

## Commit

Sem commit próprio.
