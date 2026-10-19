# T09 — Validação ponta a ponta no remoto

**Estado:** a fazer · **Depende de:** T08

## Objetivo

Repetir no projeto remoto, com e-mail real e aparelho físico, o que só aparece fora do ambiente local: entrega do e-mail, filtro de spam e o APK release.

## O que falta

- [ ] Gerar o APK apontando para o remoto: `flutter build apk --release --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<chave pública>`. Instalar num celular físico. Isso confirma a permissão `INTERNET` da T04.
- [ ] Repetir da T07 os cenários 1, 2, 3, 7, 8 e 10, com dois e-mails reais (um Gmail e outro provedor).
- [ ] Para cada e-mail recebido, anotar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn".
- [ ] Conferir no painel do Brevo o contador de envios do dia.

## Pronto quando

Entrar, criar conta e trocar e-mail funcionam no celular físico com e-mail real, e o código chega na caixa de entrada em menos de um minuto. Se cair no spam, voltar à configuração de domínio da T08 antes de fechar.

## Commit

Sem commit próprio.
