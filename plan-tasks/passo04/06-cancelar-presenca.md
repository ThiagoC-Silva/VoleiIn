# T06 — `rpc_presenca`: cancelar presença

**Estado:** a fazer · **Depende de:** T05

## Objetivo

Cancelar presença (RF15) com o prazo sem multa (RN02, RN20), a multa do cancelamento tardio (RN03), a saída da lista de espera e o anúncio da vaga liberada (RN08).

## O que já existe

- `privado.prazo_sem_multa` (T04), `privado.confirmar` (T05).
- A decisão de 2026-11-01 da T01: cancelar só até o início do jogo.

## O que falta

- [ ] Em `rpc_presenca`, `cancelar_presenca(jogo)` → `participacao_status`:
  - trava a linha do jogo; jogo `aberto` e `now() < inicio` (`jogo_ja_comecou`);
  - sem participação ativa (`confirmado` ou `lista_espera`): devolve o status atual, nada muda (RNF10);
  - em `lista_espera`: vira `cancelou_no_prazo`, `cancelado_em = now()`, sem cobrança, em qualquer momento; as posições seguintes são renumeradas;
  - `confirmado` com `now() <= privado.prazo_sem_multa(jogo)`: `cancelou_no_prazo`, cobrança `cancelada`;
  - `confirmado` depois do prazo: `cancelou_fora_do_prazo`, cobrança segue `pendente` com origem `cancelamento_tardio` e o mesmo valor (RN03); o recebedor não tem cobrança e sai sem multa;
  - saída de confirmado com fila não vazia: `vaga_liberada` a todos da lista (RN08, texto do G1);
  - `grant execute` a `authenticated`.
- [ ] Nos testes da T05, trocar os cancelamentos montados como `postgres` pela função.
- [ ] `supabase/testes/rpc_presenca.sql`:
  - no prazo: `cancelou_no_prazo` e cobrança `cancelada`; reconfirmar reabre a mesma cobrança (RN25);
  - fora do prazo (movendo `inicio` para perto de `now()`): `cancelou_fora_do_prazo`, cobrança de `cancelamento_tardio`;
  - jogo criado com o prazo já vencido: o primeiro cancelamento já é tardio (RN02);
  - prazo do grupo vale quando o jogo não tem o próprio; o do jogo vence o do grupo;
  - `cancelamento_livre_ate` no futuro torna o cancelamento sem multa mesmo depois do prazo normal;
  - lista de espera: sair vira `cancelou_no_prazo`, sem cobrança, e a fila Ana(1), Bruno(2), Carla(3) sem o Bruno fica Ana(1), Carla(2);
  - vaga liberada: cada pessoa da fila recebe um `vaga_liberada`;
  - depois do início, recusado; cancelar duas vezes não muda nada.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Cancela presença com prazo, multa e saída da fila`
