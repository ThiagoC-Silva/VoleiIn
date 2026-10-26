# T08.5 — SMTP do Resend no painel

**Estado:** a fazer · **Depende de:** T08.2, T08.4

## Objetivo

Trocar o SMTP embutido do remoto, que serve só para teste, pelo Resend. Vem antes do `config push` (T08.6), porque o teto de 30 e-mails por hora (`rate_limit.email_sent`) exige SMTP próprio.

## O que já existe

- Da documentação do Resend: host `smtp.resend.com`; portas 465 e 2465 com TLS direto, ou 25, 587 e 2587 com STARTTLS; usuário `resend`; a senha é a chave de API.
- Remetente e data da verificação anotados na T08.2; a chave de API guardada fora do repositório.
- `config.toml` sem a seção `[auth.email.smtp]`: o `config push` não toca no SMTP, e ele fica só no painel.

## O que falta

- [ ] **[Thiago]** No painel do Supabase, Authentication → SMTP:
  - ligar o SMTP próprio;
  - host `smtp.resend.com`, porta 587, usuário `resend` e a chave de API como senha;
  - endereço do remetente da T08.2 e nome "VoleiIn".
- [ ] Os campos de intervalo ou limite que a mesma tela mostrar ficam como estão: eles chegam pelo `config push` na T08.6.
- [ ] `git grep` pela parte do usuário SMTP que não é segredo: nenhum arquivo versionado a contém.

## Resultado

## Pronto quando

O painel salva o SMTP próprio sem erro, com remetente "VoleiIn".

## Commit

`Registra o SMTP do Resend no remoto`, só com o registro desta task.
