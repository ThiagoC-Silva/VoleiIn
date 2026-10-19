# T02 — Configuração local do Supabase Auth e modelos de e-mail

**Estado:** parcial · **Depende de:** T01

## Objetivo

O Supabase Auth local atende RNF06 e RNF07 por configuração: código de seis dígitos, cinco minutos, uso único, intervalo de 60 s por endereço, teto de 30 e-mails por hora no projeto, e modelos em português que mostram o código, não um link.

## O que já existe

Commitado em `e5f7f0c`:
- `supabase/config.toml`:
  - `[auth.email]`: `otp_length = 6`, `otp_expiry = 300`, `max_frequency = "60s"`, `double_confirm_changes = false`.
  - `[auth.rate_limit]`: `email_sent = 30`.
  - `[auth.email.template.confirmation]`, `magic_link`, `email_change` e `[auth.email.notification.email_changed]` com assunto em português e `content_path`.
- `supabase/templates/`: `confirmacao.html` (primeiro acesso), `codigo_acesso.html` (acesso), `troca_email.html` (código ao endereço novo), `aviso_troca_email.html` (aviso ao antigo, sem código).

## O que falta

- [ ] `supabase stop && supabase start` para o Auth recarregar o `config.toml` (o `db reset` não recarrega o Auth).
- [ ] Disparar os quatro e-mails (pode ser durante a T07) e conferir no Mailpit, em `http://127.0.0.1:54324`:
  - assunto e corpo em português;
  - código de 6 dígitos visível, sem link;
  - o aviso de troca chega ao endereço **antigo** e mostra `{{ .OldEmail }}` e `{{ .Email }}` preenchidos.
- [ ] Confirmar que nenhum segredo entrou no `config.toml` (o SMTP do Brevo é só remoto, T08).

## Pronto quando

- Os quatro e-mails aparecem no Mailpit com o conteúdo acima.
- Pedir um segundo código ao mesmo e-mail antes de 60 s é recusado pelo servidor (`over_email_send_rate_limit`).

## Commit

A configuração entrou em `e5f7f0c`. Só há commit novo se a conferência no Mailpit exigir correção.
