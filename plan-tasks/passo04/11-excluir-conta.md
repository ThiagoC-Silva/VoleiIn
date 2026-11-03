# T11 — `rpc_conta`: excluir conta

**Estado:** feito · **Depende de:** T10

## Objetivo

Excluir a própria conta (RF36, RN27, RNF04): recusar enquanto houver pendência, e, sem ela, anonimizar o perfil, apagar a credencial e a chave Pix copiada, preservando o histórico financeiro de terceiros.

## O que já existe

- A ausência deliberada de chave estrangeira entre `pessoa` e `auth.users` (`docs/stack.md`, Autenticação): apagar o usuário não leva o perfil.
- Os gatilhos de `auth.users` (`autenticacao`) e as inserções em `auth.users` como `postgres` de `supabase/testes/autenticacao.sql`.
- A decisão da T01 sobre recebedor de jogo aberto, grupos e lista de espera.

## O que falta

- [x] `supabase migration new rpc_conta`, com `excluir_conta()`, agindo sobre `auth.uid()`. Recusa, nesta ordem, cada uma com um código que a H4 usa para dizer o que falta resolver:
  - cobrança `pendente` ou `comprovante_enviado` como devedor ou credor (`cobranca_em_aberto`);
  - admin único de grupo com outros membros (`promova_outro_admin`);
  - recebedor de jogo `aberto` (`recebedor_de_jogo_aberto`).

  Sem pendência, na mesma transação:
  - `pessoa`: nome `Jogador removido`, `avatar_url`, `telefone` e `chave_pix` vazios;
  - `jogo.chave_pix_recebedor` vazia nos jogos em que ele é recebedor (RNF04);
  - participação em `lista_espera` de jogo `aberto` vira `cancelou_no_prazo`, com as filas renumeradas; em jogo encerrado ou cancelado fica como está (decidido em 2026-11-02, RN17);
  - apaga as linhas dele em `membro_grupo` e em `dispositivo_push`;
  - apaga o usuário em `auth.users` — testar que a função, dona `postgres`, tem o privilégio para isso no local; se não tiver, parar e decidir antes de contornar.
- [x] `grant execute` a `authenticated`.
- [x] `supabase/testes/rpc_conta.sql`, com o titular inserido em `auth.users` já confirmado, o que cria a `pessoa` pelo gatilho:
  - cobrança pendente como devedor, e como credor, recusam; resolvida a cobrança, a exclusão passa;
  - admin único com outro membro recusado; promovido outro admin, passa; último membro do grupo passa;
  - recebedor de jogo aberto recusado; jogo encerrado sem pendência não bloqueia;
  - depois: perfil anonimizado, chave dos jogos vazia, sem grupos, sem aparelhos, lista de espera virou `cancelou_no_prazo`, usuário fora de `auth.users`;
  - participações e cobranças encerradas continuam, apontando ao perfil anonimizado.

## Resultado

- Migração `20261103012446_rpc_conta.sql` com `excluir_conta()`, que devolve vazio.
- **Privilégio:** a função, dona `postgres`, apaga em `auth.users` no local sem contorno (`has_table_privilege('postgres', 'auth.users', 'delete')` é verdadeiro). Sessões, identidades e fatores do Auth caem em cascata pelas chaves estrangeiras do próprio Auth. O remoto é conferido na T13.
- **Idempotência:** sem a linha em `auth.users`, a conta já foi excluída, e o pedido repetido com o token ainda válido não faz nada.
- **Trava:** os grupos do titular, em ordem de id, como em promover, remover e sair, para um admin que sai ao mesmo tempo não deixar o grupo sem admin; e o jogo de cada fila aberta, antes de ler a posição, como em `cancelar_presenca`.
- **Fila:** só a de jogo `aberto` vira `cancelou_no_prazo`, com `cancelado_em` e a renumeração; a de jogo encerrado ou cancelado fica (decidido em 2026-11-02, RN17).
- **Chave:** `chave_pix_recebedor` vai a vazio em todo jogo em que ele é o recebedor, inclusive encerrado e cancelado. O `check` `jogo_chave_pix_recebedor_nao_vazia` só recusa texto vazio, então o vazio é `null`.
- **Fica:** participações, cobranças, `criador_id` e `recebedor_id` dos jogos, apontando ao perfil anonimizado, e os avisos dele em `notificacao`, que ninguém mais lê (a política só mostra ao titular). A RN27 não manda apagá-los.
- Sair dos grupos e da fila não grava aviso, como `sair_grupo` e `cancelar_presenca` da fila.
- Códigos de recusa novos: `cobranca_em_aberto`, `recebedor_de_jogo_aberto`. Reaproveitados: `promova_outro_admin`, `sem_permissao`.
- `rpc_conta.sql` com 21 asserções; `schema` 70, `rls` 69, `autenticacao` 39, `rpc_grupo` 63, `rpc_jogo` 164, `rpc_presenca` 126, `rpc_cobranca` 42.

## Pronto quando

`supabase db reset` e as oito suítes imprimem `SUCESSO`.

## Commit

`Exclui a conta anonimizando o perfil e preservando o histórico`
