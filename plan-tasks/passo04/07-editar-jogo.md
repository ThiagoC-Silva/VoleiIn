# T07 — `rpc_jogo`: editar jogo

**Estado:** a fazer · **Depende de:** T06

## Objetivo

Editar jogo (RF10) com as janelas da RN20, o recálculo da RN01, a remarcação que reabre o cancelamento sem multa e cancela as multas anteriores, e a troca de recebedor (RN20, RN24).

## O que já existe

- `privado.checar_rn15`, `privado.nascer_cobranca`, `privado.prazo_sem_multa` (T04); confirmação e cancelamento (T05, T06), para montar confirmados, fila e multas.
- Textos aprovados de `jogo_editado`, `valor_recalculado` e `vaga_liberada` (T01).

## O que falta

- [ ] Em `rpc_jogo`, `editar_jogo(jogo, ...)` — parâmetros anuláveis, e só os informados mudam:
  - **quem:** criador e admins do grupo; trocar o recebedor só o criador (RN13); trava a linha do jogo; jogo `aberto`;
  - **janelas:** vagas, data, horário, local e quadra até o início (`jogo_ja_comecou`); custo e recebedor até o encerramento;
  - **vagas:** não descem abaixo dos confirmados (`vagas_abaixo_dos_confirmados`, RN06);
  - **custo ou vagas:** recalcula `preco_por_vaga` no mesmo `update` (restrição `jogo_preco_por_vaga_arredondado`) e o `valor` de toda cobrança ativa do jogo, inclusive `cancelamento_tardio` e `falta`; com confirmados, `valor_recalculado` a eles (RN01); sem confirmados, sem aviso;
  - **vagas que aumentam com fila:** `vaga_liberada` à fila;
  - **remarcação** (data, horário, local ou quadra): `pg_advisory_xact_lock` do local novo e `checar_rn15` ignorando o próprio jogo; grava `cancelamento_livre_ate = novo inicio`; cobranças `pendente` de `cancelamento_tardio` viram `cancelada`; `jogo_editado` aos confirmados e a quem teve a multa cancelada;
  - **troca de recebedor:** exige a chave, como na criação (`recebedor_sem_chave`); reescreve `chave_pix_recebedor`; migra `credor_id` de todas as cobranças do jogo, inclusive isentas e canceladas; a cobrança do novo recebedor, se participante, vira `cancelada`; o antigo, se `confirmado`, ganha cobrança nova ou reaberta; sem aviso;
  - mudança sem efeito: nada muda, nenhum aviso.
- [ ] `grant execute` a `authenticated`.
- [ ] `supabase/testes/rpc_jogo.sql`:
  - membro comum recusado; admin edita; admin troca recebedor recusado;
  - vagas abaixo dos confirmados recusado; vagas depois do início recusado; custo depois do início aceito, depois do encerramento recusado (a T08 completa o encerrado);
  - custo de 10000 para 14000 em 10 vagas: preço e cobranças ativas passam a 1400, multa de `cancelamento_tardio` também; confirmados recebem `valor_recalculado`; sem confirmados além do criador recebedor, nenhum aviso;
  - aumentar vagas com fila avisa a fila;
  - remarcação para horário ocupado recusada; remarcação válida grava `cancelamento_livre_ate`, cancela as multas e avisa confirmados e multados; depois dela, cancelar não gera multa até o início;
  - troca de recebedor para um participante: a cobrança dele vira `cancelada`, o antigo recebedor confirmado ganha cobrança, todas as cobranças apontam ao novo credor;
  - repetir a edição não duplica aviso.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Edita jogo com recálculo, remarcação e troca de recebedor`
