# T02 — Configuração local do Supabase Auth e modelos de e-mail

**Estado:** parcial (reaberta) · **Depende de:** T01

## Objetivo

O Supabase Auth local atende RNF06 e RNF07 por configuração:
- senha de no mínimo 8 caracteres;
- código de seis dígitos, cinco minutos, uso único, intervalo de 60 s por endereço e teto de 30 e-mails por hora no projeto;
- cadastro pendente até o código;
- troca de senha só a partir de sessão recente;
- modelos em português: confirmação do cadastro, redefinição de senha e troca de e-mail mostram o código, não um link; os avisos de e-mail trocado e de senha trocada só informam.

## Reaberta em 2026-10-20 — senha e Google

O acesso passou a ser por e-mail e senha ou Google (ver as decisões no [README](README.md)). O código sai da entrada e fica no cadastro, na redefinição e na troca de e-mail. O `enable_confirmations = true` da reabertura anterior, que não chegou a ser aplicado, entra aqui junto. O provedor Google fica na T11, porque depende do cliente criado lá.

## O que já existe

Commitado em `e5f7f0c`:
- `supabase/config.toml`:
  - `[auth.email]`: `otp_length = 6`, `otp_expiry = 300`, `max_frequency = "60s"`, `double_confirm_changes = false`.
  - `[auth.rate_limit]`: `email_sent = 30`.
  - `[auth.email.template.confirmation]`, `magic_link`, `email_change` e `[auth.email.notification.email_changed]` com assunto em português e `content_path`.
- `supabase/templates/`: `confirmacao.html` (primeiro acesso), `codigo_acesso.html` (acesso), `troca_email.html` (código ao endereço novo), `aviso_troca_email.html` (aviso ao antigo, sem código).

## Sonda de 2026-10-20

- O Auth local já tinha o `config.toml` carregado (`docker inspect supabase_auth_VoleiIn`: `MAILER_OTP_EXP=300`, `MAILER_OTP_LENGTH=6`, `SMTP_MAX_FREQUENCY=1m0s`, assuntos em português, `NOTIFICATIONS_EMAIL_CHANGED_ENABLED=true`, `SECURE_EMAIL_CHANGE_ENABLED=false`).
- `GOTRUE_RATE_LIMIT_EMAIL_SENT=360000`: sem SMTP próprio, o CLI ignora `email_sent = 30`. **O teto de 30/h só se verifica no remoto**, na T09.
- Conta nova com `enable_confirmations = false`: o pedido devolve 200 vazio, o usuário já nasce com `email_confirmed_at`, `pessoa` é criada antes do código, e o e-mail que chega é o **de acesso** (`codigo_acesso.html`), não `confirmacao.html`. Por isso: confirmação ligada e perfil só na confirmação (`docs/stack.md`, Autenticação; reabertura da T03).

## O que falta

- [ ] `supabase/config.toml`:
  - `[auth]`: `minimum_password_length = 8`; `password_requirements = ""` fica.
  - `[auth.email]`: `enable_confirmations = true` e `secure_password_change = true`.
  - Sai `[auth.email.template.magic_link]`, e `supabase/templates/codigo_acesso.html` é apagado. Conferir que o Auth não tem chave para desligar só a entrada por código: `docs/stack.md` diz que não tem, e, se tiver, desligar e corrigir o stack.
  - `[auth.email.template.confirmation]`: assunto "Confirme seu cadastro no VoleiIn".
  - Novo `[auth.email.template.recovery]`: assunto "Seu código para redefinir a senha do VoleiIn", `content_path = "./supabase/templates/redefinicao_senha.html"`.
  - Novo `[auth.email.notification.password_changed]`: `enabled = true`, assunto "A senha da sua conta no VoleiIn foi trocada", `content_path = "./supabase/templates/aviso_troca_senha.html"`.
  - Comentário dos modelos: os que mostram o código são confirmação, redefinição e troca de e-mail.
- [ ] `supabase/templates/`:
  - `confirmacao.html`: o texto fala em confirmar o e-mail e concluir o cadastro, e não mais em acesso.
  - `redefinicao_senha.html`, novo:
    - o código (`{{ .Token }}`), válido por 5 minutos e uma vez só;
    - "se você não pediu, ignore: sua senha continua a mesma".
  - `aviso_troca_senha.html`, novo, sem código:
    - diz que a senha da conta de `{{ .Email }}` foi trocada e que os outros aparelhos saíram da conta;
    - se não foi você, use "Esqueci a senha" na tela de entrar, que troca a senha de novo e tira da conta quem estiver nela.
- [ ] `supabase stop && supabase start`: o `db reset` não recarrega o Auth. No `docker inspect supabase_auth_VoleiIn`, conferir:
  - autoconfirmação desligada (`MAILER_AUTOCONFIRM=false`);
  - senha mínima 8;
  - reautenticação para troca de senha ligada;
  - assuntos novos e aviso de senha ligado.

  O nome exato de cada variável depende da versão do CLI; o que vale é o valor.
- [ ] Conferir que a conta nova recebe `confirmacao.html`, fica sem `email_confirmed_at` e sem `pessoa` até o código, e ganha `pessoa` ao confirmá-lo.
- [ ] Disparar os cinco e-mails e conferir no Mailpit, em `http://127.0.0.1:54324`. Pode ser durante a T07.
  - Assunto e corpo em português.
  - Confirmação, redefinição e troca de e-mail mostram o código de 6 dígitos, sem link.
  - O aviso de troca de e-mail chega ao endereço **antigo** e mostra `{{ .OldEmail }}` e `{{ .Email }}` preenchidos.
  - O aviso de senha trocada chega depois da redefinição.
- [ ] Confirmar que nenhum segredo entrou no `config.toml`. O SMTP do Brevo é só remoto (T08), e o segredo do Google mora em `supabase/.env` (T11).

## Pronto quando

- Os cinco e-mails aparecem no Mailpit com o conteúdo acima.
- Pedir um segundo código ao mesmo e-mail antes de 60 s é recusado pelo servidor (`over_email_send_rate_limit`).
- `signUp` com senha de 7 caracteres é recusado (`weak_password`).

## Commit

A configuração inicial entrou em `e5f7f0c`. A reabertura vai no mesmo commit da T03, `Cria o perfil na confirmação do cadastro e aceita senha e Google`, porque um sem o outro não resolve.
