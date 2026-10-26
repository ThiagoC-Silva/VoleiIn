# T08.6 — Configuração do Auth e do Google pelo `config push`

**Estado:** a fazer · **Depende de:** T08.5

## Objetivo

Deixar o Auth do remoto igual ao local validado na T07, a partir do `config.toml` versionado, em vez de repetir à mão no painel. O SMTP fica de fora: está só no painel (T08.5).

## O que já existe

- `supabase/config.toml` com a configuração da T02 e o provedor Google da T11; o segredo do Google em `supabase/.env`.
- Os cinco modelos em `supabase/templates/`, com os assuntos no `config.toml`.
- `supabase config diff` mostra o diff sem gravar. O `config push` só envia o que o arquivo declara e pede confirmação por recurso.

## O que falta

- [ ] **Decidir `skip_nonce_check`** com o Thiago (README, "A decidir"), antes de qualquer push.
- [ ] `supabase config diff`, e conferir que o diff traz:
  - OTP de 6 dígitos, validade de 300 s;
  - 60 s entre envios (`max_frequency`) e teto de 30 e-mails por hora (`rate_limit.email_sent`);
  - senha mínima de 8 caracteres, sem requisitos de composição;
  - `double_confirm_changes = false`, `secure_password_change = true`, `enable_confirmations = true`;
  - os modelos de confirmação, redefinição de senha e troca de e-mail, mais os avisos de e-mail trocado e de senha trocada, com os assuntos do `config.toml`. O de magic link fica no padrão do serviço;
  - Google ligado, com o `client_id` do cliente web e o segredo lido de `supabase/.env`.
- [ ] Anotar o que mais o diff trouxer, para decidir item a item com o Thiago. Esperados: `site_url = "http://127.0.0.1:3000"` (o fluxo não usa link, mas o remoto ficaria com um endereço local), schemas expostos da API e ajustes de `[db]` e `[storage]`. **Parar** se aparecer algo de SMTP.
- [ ] `supabase config push`, aceitando só os recursos conferidos. O CLI aceita `y`/`n` pela entrada padrão; se não aceitar, o Thiago roda com `!`.
- [ ] `GET https://<ref>.supabase.co/auth/v1/settings` com a chave pública: `google` ligado, `mailer_autoconfirm` falso.
- [ ] **[Thiago]** No painel, conferir:
  - Authentication → Providers → Google ligado, com Client ID e Client Secret. Se o diff não tiver trazido o Google, preencher aqui. O fluxo é por ID token, sem URL de retorno;
  - os modelos em português, com `{{ .Token }}`;
  - o SMTP da T08.5 continua ligado;
  - "Leaked password protection" desligada.
- [ ] `supabase config diff` de novo: sem diferença, salvo o que tiver sido recusado de propósito.

## Resultado

## Pronto quando

O `config diff` volta sem diferença nos itens da lista, o provedor Google aparece ligado no painel, e o SMTP do Resend continua configurado.

## Commit

Se o `config.toml` mudar (por exemplo, para o `skip_nonce_check`): `Ajusta a configuração do Auth para o remoto`. Se não: `Registra a configuração do Auth no remoto`.
