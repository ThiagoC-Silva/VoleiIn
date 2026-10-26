# T08.7 — Cadastro com e-mail real e fechamento da T08

**Estado:** a fazer · **Depende de:** T08.6

## Objetivo

Provar com um cadastro só que o remoto envia o código pelo Resend, com o modelo em português, e fechar a T08. A validação completa, com o celular e o Google, é da T09.

## O que já existe

- `supabase/testes/autenticacao_api.sh`, com `AUTH_URL`, `CHAVE`, `MAILPIT_URL` e `PSQL` por ambiente. Sem `MAILPIT_URL`, pede o código pelo terminal (`/dev/tty`), o que nunca foi exercitado e fica para a T09.
- O teto de 30 e-mails por hora: esta task gasta um.

## O que falta

- [ ] Chave pública do remoto, por `supabase projects api-keys --project-ref <ref>` ou pelo painel.
- [ ] Cadastro pela API com um e-mail real do Thiago, pedido na hora e fora de arquivo versionado: `POST /signup` com senha e nome. Espera-se 200, sem sessão.
- [ ] **[Thiago]** Ler o e-mail e informar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn";
  - se o assunto é "Confirme seu cadastro no VoleiIn" e o corpo está em português, com as seis casas;
  - o código.
- [ ] `POST /verify` (`type: email`) com o código: 200, com sessão.
- [ ] **[Thiago]** No editor SQL do painel: a linha em `pessoa` com o id de `auth.users` e o nome do cadastro.
- [ ] **[Thiago]** Nos registros do Resend, o envio aparece com status de entregue.
- [ ] **[Thiago]** No cabeçalho do e-mail recebido (no Gmail, "Mostrar original"): `SPF: PASS`, `DKIM: PASS` e `DMARC: PASS`. Sem isso, a verificação da T08.2 não está de pé.
- [ ] **[Thiago]** Depois que o e-mail real passar, voltar o `_dmarc.voleiin.com.br` no Registro.br de `p=none` para `v=DMARC1; p=reject;`, e repetir um cadastro para confirmar que continua chegando.
- [ ] Se o e-mail caiu no spam, **não fechar**: voltar à decisão de remetente da T08.2.
- [ ] Fechamento:
  - [`08-projeto-remoto-resend.md`](../passo-3/08-projeto-remoto-resend.md): caixas marcadas e estado "feito";
  - [README do passo 3](../passo-3/README.md): T08 → feito;
  - T09: o ref, de onde vem a chave pública, e a decisão do `skip_nonce_check`, se ela pedir conferência no celular;
  - T10: o que entra em "Decisões de implementação" (o Auth do remoto vem do `config.toml` pelo `config push`, e o SMTP só pelo painel) e o que fica em "Aberto".

## Resultado

## Pronto quando

- `supabase migration list` mostra as cinco migrações nos dois lados (T08.4).
- Um cadastro no remoto recebe o código por e-mail real, com o modelo em português, na caixa de entrada.
- O provedor Google aparece ligado no painel (T08.6).

## Commit

`Liga o projeto remoto e o SMTP do Resend`
