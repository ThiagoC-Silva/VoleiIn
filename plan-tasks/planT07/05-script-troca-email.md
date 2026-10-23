# T07.5 — Script: troca de e-mail, modelos e impostor (cenários 13 a 16)

**Estado:** feito · **Depende de:** T07.4

## Objetivo

Fechar o trilho de servidor: a troca de e-mail (RF35, RNF07), o conteúdo dos cinco e-mails da T02 e a parte do cenário 19 que só se faz por API.

## O que já existe

- `double_confirm_changes = false`: o código vai só para o endereço novo.
- O aviso de e-mail trocado ligado em `[auth.email.notification.email_changed]`.

## O que falta

- [x] **Cenários 13, 14 e 15** — Carla confirmada, com uma segunda sessão (B) e duas linhas em `dispositivo_push`:
  - `PUT /user` com `email: carla2.<epoch>@…` pela sessão A;
  - o código chega **só** no endereço novo ("Confirme a troca de e-mail no VoleiIn"); nada no antigo ainda;
  - as linhas de `dispositivo_push` **continuam lá** depois do pedido (15);
  - `/verify` (`type: email_change`, e-mail novo) → `/logout?scope=others`;
  - esperado: `GET /user` de A devolve o e-mail novo (13); o refresh de B é recusado (14); as linhas sumiram (15); o aviso "O e-mail da sua conta no VoleiIn foi trocado" chega no endereço antigo.
- [x] **Cenário 16** — `PUT /user` da Carla com o e-mail do Bruno: `email_exists`, e nenhum e-mail.
- [x] **Os cinco modelos** — para cada um dos cinco assuntos de `config.toml`, a mensagem recebida na rodada tem o assunto exato, corpo em português e, nos três de código, seis dígitos. Conferência feita no fim, sobre as mensagens já lidas.
- [x] **`--impostor <gmail>`** — só faz `/signup` com senha e nome "Impostor" no Gmail dado, sem confirmar, e imprime o id; confere que `pessoa` não tem a linha. Não entra na contagem de cenários; é usado na T07.9.
- [x] Atualizar a linha de `supabase/CLAUDE.md` com as opções finais.

## Resultado

Rodada contra o local em 2026-10-23, Auth v2.197.0:

| Cenário | Observado |
| --- | --- |
| 13 | `PUT /user` 200, ainda com o e-mail antigo em `email` e o novo em `new_email`. "Confirme a troca de e-mail no VoleiIn" chega só no endereço novo; nada no antigo em 5 s. `/verify` (`type: email_change`) 200 **com sessão nova**; `/logout?scope=others` por ela, 204. `GET /user` dessa sessão devolve o e-mail novo, e a renovação dela dá 200. "O e-mail da sua conta no VoleiIn foi trocado" chega no endereço antigo |
| 14 | A troca **sozinha não derruba** B: a renovação de B entre o `/verify` e o logout deu 200. Depois do `/logout?scope=others`, 400 `refresh_token_not_found` |
| 15 | As duas linhas de `dispositivo_push` continuam depois do pedido e somem com a confirmação |
| 16 | `PUT /user` com o e-mail do Bruno: 422 `email_exists`; nenhum e-mail ao Bruno nem à Carla em 5 s cada |
| modelos | Com `--so 12,13`, 5 de 5: assunto exato, o título `<h2>` do modelo no corpo, nenhum `{{` sem preencher e, nos três de código, seis casas |
| `--impostor` | Com endereço de teste: 200, id impresso; `pessoa` sem a linha, e em `auth.users` não confirmado, `nome` "Impostor" e senha gravada. Com endereço já confirmado: `FALHOU` mandando apagar a conta pelo SQL de `07-e2e-local.md` |

- **Onde o roteiro mudou**: a task pedia `GET /user` pela sessão A. Mas o `/verify` de troca devolve uma sessão nova, e o `verifyOTP` do app a põe no lugar da A antes do `signOut(others)` (`confirmarTrocaEmail`, `app/lib/dados/auth_repositorio.dart:106`). O script faz o mesmo: o logout sai da sessão do código, e é ela que se confere no 13. A sessão A cai junto com B (renovação 400 `refresh_token_not_found`), o que só se anota: no aparelho ela já foi substituída.
- **Para a T07.6 e a T07.8**: ao contrário da troca de senha (T07.4), no 14 o `signOut(others)` do `confirmarTrocaEmail` **é o que derruba** as outras sessões. Ele não pode sair do app.
- O 13, o 14 e o 15 partilham uma só troca (`troca_de_email`), feita na primeira vez que qualquer um deles é pedido; cada um conta como um cenário.
- O 16 usa o Bruno do 9, que virou global (`BRUNO`). Com `--so 16` sem o 9, o Bruno é criado por `bruno_confirmado`, o que gasta um e-mail.
- Os cinco assuntos ficam juntos no topo dos cenários, com o modelo de cada um em `MODELOS`. O "corpo em português" se confere pelo título `<h2>` do arquivo em `supabase/templates/`, lido na hora: se o Auth mandasse o modelo padrão em inglês, o título não estaria lá.
- A conferência dos modelos roda no fim, fora do `--so`, sobre as mensagens lidas. Na rodada inteira, faltar um modelo é `FALHOU`; com `--so`, o que falta entra em "Para anotar". Sem `MAILPIT_URL`, conta como pulada.
- `aparelhos_inventados` vem do 9 e agora serve também ao 15. O `token_fcm` inventado leva o id da pessoa no lugar da época, para dois cenários da mesma rodada não repetirem o token.
- Ordem: 12, 13 a 16 e por último o 10. Sozinho, o 10 pede uma redefinição para a Carla que ninguém lê, e o "nada no antigo" do 13 a acusaria.
- E-mails: `--so 13,14,15,16` gasta 4 (Carla 1, troca 1, aviso 1, Bruno 1) e leva cerca de 16 s; `--so 12,13`, 5. Na rodada inteira o 13 a 16 somam 2, porque Carla e Bruno já existem: **16 no total**, para a T07.6 refazer a conta contra os 30 por hora. Esta task gastou 13 na hora, com a sonda e o teste do `--impostor`.

## Pronto quando

`autenticacao_api.sh --so 13,14,15,16` passa, e `--impostor` cria o cadastro pendente sem perfil.

## Commit

`Cobre a troca de e-mail e os modelos no roteiro da API`
