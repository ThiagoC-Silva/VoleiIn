# Research: etapa A da fatia 6

## R1. Ordem das validações

**Decisão:** autenticação; existência, que inclui poder ver o valor (`NOT_FOUND`); papel (`NOT_CHARGE_RECEIVER`); estado (`CHARGE_NOT_PENDING` ou `CHARGE_NOT_REVERTIBLE`). É a ordem da seção 1 do contrato. Quem pode ver o jogo e não o valor (o Bruno e o Diego do PG02) recebe `NOT_FOUND` pela `private.can_view_charge`.

## R2. Bloqueio

**Decisão:** um auxiliar, `private.lock_charge(p_charge_id, p_uid)`, bloqueia o jogo (`lock_game`) e depois o valor (`for update`), confere `can_view_charge` e o papel, e devolve a linha relida. A visibilidade e o papel são conferidos **depois** do bloqueio: uma troca de recebedor que estava em curso já terminou. É a ordem de `waive_penalty` e `change_receiver`, e por isso o C09 tem só uma transição. A função fica em `private`, sem `execute` para o app.

## R3. "Marcação do próprio recebedor" (RN85)

**Decisão:** basta `paid_via = manual` e quem chama ser o `receiver_id`. Só o `receiver_id` marca (`mark_charge_paid`), e `change_receiver` não mexe em valor Pago (RN31.2): quem marcou é sempre o `receiver_id` do valor. Conferir o autor em `charge_events` repetiria isso.

## R4. Pagador que virou o recebedor do jogo (decisão do responsável em 24/11/2026)

**Problema:** Ana marca o Bruno como pago e depois passa o recebimento para ele. Se a Ana revertesse, o recebedor do jogo passaria a dever, contra o "Pronto quando" da fatia 5 ("o recebedor nunca recebe multa nem valor a pagar"), com a Ana devendo a ele a mesma parte. A RN85 e o contrato não tratavam o caso.

**Decisão:** `revert_charge` devolve `CHARGE_NOT_REVERTIBLE` enquanto o pagador for o recebedor atual do jogo. O acerto entre os dois fica fora do app, como na RN31.6. Se o recebimento passar a outra pessoa, a reversão volta a valer. RN85, `contratos-api.md` (seção 6) e o cenário novo PG07 registram a decisão. PG01 a PG06 não mudam.

**No app (sessão 3):** **Reverter pagamento** segue a tabela 9.5 do `telas.md`. A recusa vira `errorChargeNotRevertible` no `SnackBar`, como já estava previsto.

## R5. Efeitos

**Decisão:**
- `mark_charge_paid`: `status = paid`, `paid_at = now()`, `paid_via = manual`; `charge_events` de `pending` para `paid`, com quem marcou.
- `revert_charge`: `status = pending`, `paid_at` e `paid_via` nulos; `charge_events` de `paid` para `pending`. `auto_reads_used` e `receiver_id` não mudam.
- Os dois notificam só o pagador, com o `data` da seção 6 do contrato, montado sobre `private.game_notification_data`. Sem `audit_log`: o contrato não o cita, e `charge_events` já guarda quem e quando.

## R6. Seed

**Decisão:** a Ana marca como pago o `share` da Carla no "Quinta concluído" (`...0208`), com `mark_charge_paid`. O Rateio da Ana mostra, na mesma tela, o Bruno Pendente (**Marcar como pago**) e a Carla Paga (**Reverter pagamento**). Nenhum fluxo de integração usa esse jogo.

## R7. Base dos testes

**Decisão:** o jogo concluído do R01 é inserido direto, com Ana, Bruno, Carla e Fábio na lista e os três valores que a base pede, todos de 2.084 (só eles importam aos cenários). O Edu é admin do jogo sem estar na lista. Cada cenário roda entre um *savepoint* e a volta para ele. O PG03 e o PG05 gravam o status direto, como `postgres`.

O C09 é a forma da seção 8: a multa Pendente de uma conta, a admin que não é recebedora isenta e a recebedora marca como pago. Fica em `payments_test.ts`. A forma da fatia 5 (duas isenções) continua em `completion_test.ts`.
