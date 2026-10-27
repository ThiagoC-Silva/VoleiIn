# T08.5 — SMTP do Resend no painel

**Estado:** feito · **Depende de:** T08.2, T08.4

## Objetivo

Trocar o SMTP embutido do remoto, que serve só para teste, pelo Resend. Vem antes do `config push` (T08.6), porque o teto de 30 e-mails por hora (`rate_limit.email_sent`) exige SMTP próprio.

## O que já existe

- Da documentação do Resend: host `smtp.resend.com`; portas 465 e 2465 com TLS direto, ou 25, 587 e 2587 com STARTTLS; usuário `resend`; a senha é a chave de API.
- Remetente e data da verificação anotados na T08.2; a chave de API guardada fora do repositório.
- `config.toml` sem a seção `[auth.email.smtp]`: o `config push` não toca no SMTP, e ele fica só no painel.

## O que falta

- [x] **[Thiago]** No painel do Supabase, Authentication → SMTP:
  - ligar o SMTP próprio;
  - host `smtp.resend.com`, porta 587, usuário `resend` e a chave de API como senha;
  - endereço do remetente da T08.2 e nome "VoleiIn".
- [x] Os campos de intervalo ou limite que a mesma tela mostrar ficam como estão: eles chegam pelo `config push` na T08.6.
- [x] `git grep` pela parte do usuário SMTP que não é segredo: nenhum arquivo versionado a contém.

## Resultado

Feito em 2026-10-27.

- **Remetente decidido aqui:** `nao-responda@mail.voleiin.com.br`. A T08.2 tinha fixado só o subdomínio. O `mail.voleiin.com.br` não tem MX (conferido em `8.8.8.8`; só o `send.mail` tem, o de devolução do Resend), então nenhum endereço nele recebe resposta, e o nome avisa isso a quem clicar em "responder".
- **[Thiago]** No painel, SMTP próprio ligado e salvo sem erro: host `smtp.resend.com`, porta 587, usuário `resend`, a chave de API como senha, remetente `nao-responda@mail.voleiin.com.br` com nome "VoleiIn".
- Os campos de intervalo e limite da mesma tela ficaram como estavam; chegam pelo `config push` na T08.6.
- `git grep -E "re_[A-Za-z0-9_]{8,}"`: nenhuma chave do Resend em arquivo versionado. Os únicos resultados são `secure_password_change`, que casa com o padrão por acaso.

## Pronto quando

O painel salva o SMTP próprio sem erro, com remetente "VoleiIn".

## Commit

`Registra o SMTP do Resend no remoto`, só com o registro desta task.
