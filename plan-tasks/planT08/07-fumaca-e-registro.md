# T08.7 — Cadastro com e-mail real e fechamento da T08

**Estado:** a fazer · **Depende de:** T08.6

## Objetivo

Provar com um cadastro só que o remoto envia o código pelo Resend, com o modelo em português, e fechar a T08. A validação completa, com o celular e o Google, é da T09.

## O que já existe

- `supabase/testes/autenticacao_api.sh` **não serve aqui**: monta os endereços como `nome.<época>@EMAIL_BASE`, sem como apontar para um endereço escolhido; o `--impostor` grava o nome "Impostor"; e, sem `MAILPIT_URL`, pede o código por `/dev/tty`, que não existe no Bash do Claude nem no modo `!`. O cadastro e a confirmação vão por `curl` direto, com o mesmo corpo do `json_cadastro` (`{email, password, data: {nome}}`) e do `json_codigo` (`{type: "email", email, token}`). O modo sem `MAILPIT_URL` fica para a T09.
- O teto de 30 e-mails por hora: esta task gasta dois, o cadastro e a redefinição depois do `p=reject`.
- Ninguém apaga a `pessoa` quando o usuário sai de `auth.users`: não há chave estrangeira entre as duas (de propósito) nem gatilho de exclusão. Usuário de teste criado no remoto fica.

## O que falta

- [ ] Chave pública do remoto, por `supabase projects api-keys --project-ref <ref>` ou pelo painel.
- [ ] **Endereço do cadastro: o Gmail do Thiago com sufixo `+`**, como `<usuario>+t087@gmail.com`, pedido na hora e fora de arquivo versionado. Chega na mesma caixa, mas é outro e-mail para o Auth. Deixa o Gmail principal sem conta para os cenários 1 e 17 da T09, e não sobra perfil órfão, já que apagar o usuário depois deixaria a `pessoa`.
- [ ] `POST /signup` por `curl` com esse endereço, senha e nome. Espera-se 200, sem sessão.
- [ ] **[Thiago]** Ler o e-mail e informar:
  - quanto tempo levou para chegar;
  - se caiu na caixa de entrada ou no spam;
  - se o remetente aparece como "VoleiIn";
  - se o assunto é "Confirme seu cadastro no VoleiIn" e o corpo está em português, com as seis casas;
  - o código.
- [ ] `POST /verify` (`type: email`) com o código: 200, com sessão.
- [ ] A linha em `pessoa` com o id de `auth.users` e o nome do cadastro, por consulta só de leitura pelo MCP do Supabase (`execute_sql`). Se o MCP não estiver autenticado, **[Thiago]** no editor SQL do painel, com a consulta que o Claude preparar.
- [ ] **[Thiago]** Nos registros do Resend, o envio aparece com status de entregue.
- [ ] **[Thiago]** No cabeçalho do e-mail recebido (no Gmail, "Mostrar original"): `SPF: PASS`, `DKIM: PASS` e `DMARC: PASS`. Sem isso, a verificação da T08.2 não está de pé.
- [ ] **[Thiago]** Depois que o e-mail real passar, voltar o `_dmarc.voleiin.com.br` no Registro.br de `p=none` para `v=DMARC1; p=reject;`. Conferir por consulta de DNS em `8.8.8.8` que o `p=reject` está publicado.
- [ ] Com o `p=reject` no ar, `POST /recover` para o mesmo endereço. Repetir o cadastro não serviria: com o e-mail já confirmado, o serviço não envia nada. A redefinição confirma que o envio continua chegando e ainda exercita outro modelo.
- [ ] **[Thiago]** Ler o segundo e-mail: caixa de entrada ou spam, assunto "Seu código para redefinir a senha do VoleiIn", e `DMARC: PASS` no original. O código não precisa ser usado.
- [ ] Se algum e-mail caiu no spam, **não fechar**:
  - com SPF, DKIM e DMARC passando, o mais provável é falta de reputação do domínio novo, não o remetente: anotar, marcar "não é spam" no Gmail e decidir com o Thiago;
  - se alguma autenticação falhou, voltar à configuração de DNS da T08.2.
- [ ] Fechamento:
  - [`08-projeto-remoto-resend.md`](../passo-3/08-projeto-remoto-resend.md): caixas marcadas e estado "feito";
  - [README do passo 3](../passo-3/README.md): T08 → feito;
  - T09: o ref, de onde vem a chave pública, a decisão do `skip_nonce_check`, se ela pedir conferência no celular, e que o endereço com `+` já tem conta no remoto, sem uso nos cenários de lá;
  - T10: o que entra em "Decisões de implementação" (o Auth do remoto vem do `config.toml` pelo `config push`, e o SMTP só pelo painel) e o que fica em "Aberto".

## Resultado

## Pronto quando

- `supabase migration list` mostra as cinco migrações nos dois lados (T08.4).
- Um cadastro no remoto recebe o código por e-mail real, com o modelo em português, na caixa de entrada.
- O original do e-mail mostra `SPF: PASS`, `DKIM: PASS` e `DMARC: PASS`.
- O `_dmarc.voleiin.com.br` está de volta a `p=reject`, e um segundo envio, a redefinição, chega na caixa de entrada depois disso.
- O provedor Google aparece ligado no painel (T08.6).

## Commit

`Liga o projeto remoto e o SMTP do Resend`
