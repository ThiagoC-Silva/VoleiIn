# T11 — `rpc_conta`: excluir conta

**Estado:** a fazer · **Depende de:** T10

## Objetivo

Excluir a própria conta (RF36, RN27, RNF04): recusar enquanto houver pendência, e, sem ela, anonimizar o perfil, apagar a credencial e a chave Pix copiada, preservando o histórico financeiro de terceiros.

## O que já existe

- A ausência deliberada de chave estrangeira entre `pessoa` e `auth.users` (`docs/stack.md`, Autenticação): apagar o usuário não leva o perfil.
- Os gatilhos de `auth.users` (`autenticacao`) e as inserções em `auth.users` como `postgres` de `supabase/testes/autenticacao.sql`.
- A decisão da T01 sobre recebedor de jogo aberto, grupos e lista de espera.

## O que falta

- [ ] `supabase migration new rpc_conta`, com `excluir_conta()`, agindo sobre `auth.uid()`. Recusa, nesta ordem, cada uma com um código que a H4 usa para dizer o que falta resolver:
  - cobrança `pendente` ou `comprovante_enviado` como devedor ou credor (`cobranca_em_aberto`);
  - admin único de grupo com outros membros (`promova_outro_admin`);
  - recebedor de jogo `aberto` (`recebedor_de_jogo_aberto`).

  Sem pendência, na mesma transação:
  - `pessoa`: nome `Jogador removido`, `avatar_url`, `telefone` e `chave_pix` vazios;
  - `jogo.chave_pix_recebedor` vazia nos jogos em que ele é recebedor (RNF04);
  - participação em `lista_espera` de jogo `aberto` vira `cancelou_no_prazo`, com as filas renumeradas; em jogo encerrado ou cancelado fica como está (decidido em 2026-11-02, RN17);
  - apaga as linhas dele em `membro_grupo` e em `dispositivo_push`;
  - apaga o usuário em `auth.users` — testar que a função, dona `postgres`, tem o privilégio para isso no local; se não tiver, parar e decidir antes de contornar.
- [ ] `grant execute` a `authenticated`.
- [ ] `supabase/testes/rpc_conta.sql`, com o titular inserido em `auth.users` já confirmado, o que cria a `pessoa` pelo gatilho:
  - cobrança pendente como devedor, e como credor, recusam; resolvida a cobrança, a exclusão passa;
  - admin único com outro membro recusado; promovido outro admin, passa; último membro do grupo passa;
  - recebedor de jogo aberto recusado; jogo encerrado sem pendência não bloqueia;
  - depois: perfil anonimizado, chave dos jogos vazia, sem grupos, sem aparelhos, lista de espera virou `cancelou_no_prazo`, usuário fora de `auth.users`;
  - participações e cobranças encerradas continuam, apontando ao perfil anonimizado.

## Pronto quando

`supabase db reset` e as oito suítes imprimem `SUCESSO`.

## Commit

`Exclui a conta anonimizando o perfil e preservando o histórico`
