# T08.6 — Configuração do Auth e do Google pelo `config push`

**Estado:** feito · **Depende de:** T08.5

## Objetivo

Deixar o Auth do remoto igual ao local validado na T07, a partir do `config.toml` versionado, em vez de repetir à mão no painel. O SMTP fica de fora: está só no painel (T08.5).

## O que já existe

- `supabase/config.toml` com a configuração da T02 e o provedor Google da T11; o segredo do Google em `supabase/.env`.
- Os cinco modelos em `supabase/templates/`, com os assuntos no `config.toml`.
- `supabase config diff` mostra o diff sem gravar. O `config push` só envia o que o arquivo declara e pede confirmação por recurso.

## O que falta

- [x] **Decidir `skip_nonce_check`** com o Thiago (README, "A decidir"), antes de qualquer push.
- [x] `supabase config diff`, e conferir que o diff traz:
  - OTP de 6 dígitos, validade de 300 s;
  - 60 s entre envios (`max_frequency`) e teto de 30 e-mails por hora (`rate_limit.email_sent`);
  - senha mínima de 8 caracteres, sem requisitos de composição;
  - `double_confirm_changes = false`, `secure_password_change = true`, `enable_confirmations = true`;
  - os modelos de confirmação, redefinição de senha e troca de e-mail, mais os avisos de e-mail trocado e de senha trocada, com os assuntos do `config.toml`. O de magic link fica no padrão do serviço;
  - Google ligado, com o `client_id` do cliente web e o segredo lido de `supabase/.env`.
- [x] Anotar o que mais o diff trouxer, para decidir item a item com o Thiago. Esperados: `site_url = "http://127.0.0.1:3000"` (o fluxo não usa link, mas o remoto ficaria com um endereço local), schemas expostos da API e ajustes de `[db]` e `[storage]`. **Parar** se aparecer algo de SMTP.
- [x] `supabase config push`, aceitando só os recursos conferidos. O CLI aceita `y`/`n` pela entrada padrão; se não aceitar, o Thiago roda com `!`.
- [x] `GET https://<ref>.supabase.co/auth/v1/settings` com a chave pública: `google` ligado, `mailer_autoconfirm` falso.
- [x] **[Thiago]** No painel, conferir:
  - Authentication → Providers → Google ligado, com Client ID e Client Secret. Se o diff não tiver trazido o Google, preencher aqui. O fluxo é por ID token, sem URL de retorno;
  - os modelos em português, com `{{ .Token }}`;
  - o SMTP da T08.5 continua ligado;
  - "Leaked password protection" desligada.
- [x] `supabase config diff` de novo: sem diferença, salvo o que tiver sido recusado de propósito.

## Resultado

Feito em 2026-10-27, com o Supabase CLI `3.0.0-next.20`.

- **`skip_nonce_check = true` também no remoto**, igual ao local. O app chama `signInWithIdToken` sem nonce. Com a checagem ligada, o serviço só recusaria um token que viesse com nonce, e o único caminho validado no celular é o `true`. O ganho de ligar a checagem seria pequeno, e o risco seria quebrar a entrada pelo Google na T09. O `config.toml` não mudou de valor, só o comentário.
- **O push confirma por recurso, não por chave.** Ele perguntou só por `auth` e `storage`: API e banco já estavam iguais, e o pooler não tem campo na API de gerenciamento.
  - `auth`, **aceito**. Trouxe tudo o que a lista pedia: OTP de 6 dígitos e 300 s, senha mínima 8 sem requisitos, `double_confirm_changes = false`, `secure_password_change = true`, os assuntos e o conteúdo dos cinco modelos, os avisos de troca ligados, e o Google com `client_id` e segredo de `supabase/.env`. `max_frequency` e `enable_confirmations` já estavam iguais. Vieram junto, aceitos:
    - `site_url`, de `localhost:3000` para `127.0.0.1:3000`, e `additional_redirect_urls = ["https://127.0.0.1:3000"]`. São endereços locais sem efeito, porque o fluxo é por código e não usa link;
    - TOTP e confirmação por SMS desligados, igual ao local, porque o app não usa nenhum dos dois;
    - `external.google.email_optional = false`, gravado no padrão pelo CLI junto com o Google.
  - `storage`, **recusado**: `vector.enabled` passaria de `false` a `true`, e o MVP não usa.
  - Pooler (`default_pool_size`, `max_client_conn`): o CLI não envia, e ficou no padrão do serviço, de propósito.
- **SMTP:** aparece no diff só como `remote_only`, não declarado. O push não o tocou.
- **`rate_limit.email_sent` não é gerenciado pelo `config push`.** O CLI não compara nem envia esse campo, então o teto fica só no painel, como o SMTP.
- `GET /auth/v1/settings` com a chave pública: `google: true`, `email: true`, `mailer_autoconfirm: false`.
- **[Thiago]** Conferido no painel: o Google está ligado, com Client ID e Client Secret. O modelo de confirmação está em português, com `{{ .Token }}`. O SMTP do Resend continua ligado, com host e remetente corretos. O limite de envio de e-mails está em 30 por hora. "Leaked password protection" está desligada.
- `supabase config diff` de novo: nenhuma diferença no auth. Sobram o SMTP (`remote_only`), o pooler e o storage vector, recusados de propósito.

## Pronto quando

O `config diff` volta sem diferença nos itens da lista, o provedor Google aparece ligado no painel, e o SMTP do Resend continua configurado.

## Commit

Se o `config.toml` mudar (por exemplo, para o `skip_nonce_check`): `Ajusta a configuração do Auth para o remoto`. Se não: `Registra a configuração do Auth no remoto`.
