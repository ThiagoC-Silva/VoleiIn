# T07.5 — Script: troca de e-mail, modelos e impostor (cenários 13 a 16)

**Estado:** a fazer · **Depende de:** T07.4

## Objetivo

Fechar o trilho de servidor: a troca de e-mail (RF35, RNF07), o conteúdo dos cinco e-mails da T02 e a parte do cenário 19 que só se faz por API.

## O que já existe

- `double_confirm_changes = false`: o código vai só para o endereço novo.
- O aviso de e-mail trocado ligado em `[auth.email.notification.email_changed]`.

## O que falta

- [ ] **Cenários 13, 14 e 15** — Carla confirmada, com uma segunda sessão (B) e duas linhas em `dispositivo_push`:
  - `PUT /user` com `email: carla2.<epoch>@…` pela sessão A;
  - o código chega **só** no endereço novo ("Confirme a troca de e-mail no VoleiIn"); nada no antigo ainda;
  - as linhas de `dispositivo_push` **continuam lá** depois do pedido (15);
  - `/verify` (`type: email_change`, e-mail novo) → `/logout?scope=others`;
  - esperado: `GET /user` de A devolve o e-mail novo (13); o refresh de B é recusado (14); as linhas sumiram (15); o aviso "O e-mail da sua conta no VoleiIn foi trocado" chega no endereço antigo.
- [ ] **Cenário 16** — `PUT /user` da Carla com o e-mail do Bruno: `email_exists`, e nenhum e-mail.
- [ ] **Os cinco modelos** — para cada um dos cinco assuntos de `config.toml`, a mensagem recebida na rodada tem o assunto exato, corpo em português e, nos três de código, seis dígitos. Conferência feita no fim, sobre as mensagens já lidas.
- [ ] **`--impostor <gmail>`** — só faz `/signup` com senha e nome "Impostor" no Gmail dado, sem confirmar, e imprime o id; confere que `pessoa` não tem a linha. Não entra na contagem de cenários; é usado na T07.9.
- [ ] Atualizar a linha de `supabase/CLAUDE.md` com as opções finais.

## Resultado

_Preenchido na execução._

## Pronto quando

`autenticacao_api.sh --so 13,14,15,16` passa, e `--impostor` cria o cadastro pendente sem perfil.

## Commit

`Cobre a troca de e-mail e os modelos no roteiro da API`
