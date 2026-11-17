# Research: etapa B da fatia 4

## R1. Ordem dos erros de `leave_game`

**Decisão:** autenticação, `NOT_FOUND` (`lock_game`), `GAME_NOT_OPEN`, `NOT_PARTICIPANT` (sem passagem `active`), `RECEIVER_LOCKED`, `LIST_LOCKED` (`ends_at <= now()`). É a ordem da assinatura em `docs/contratos-api.md` e a da seção 1 (existência, papel, estado, tempo). O recebedor recebe `RECEIVER_LOCKED` também depois do fim, o que nenhum cenário contradiz.

## R2. Fronteiras de tempo

**Decisão:** antes do início é `starts_at > now()`; `late_cancellation = now() > cancellation_deadline` (T01, T02); entre o início e o fim é `starts_at <= now() < ends_at` (T07 a T09); `ends_at <= now()` dá `LIST_LOCKED` (T10). Quem saiu depois do início fica com `left_at = now()`, porque a *constraint* `game_participants_active` exige `left_at` fora de `active`.

## R3. Aviso à espera

**Decisão:** `leave_game` (antes do início) e `remove_participant` reusam `private.notify_waitlist(game, 'slot_freed')` da etapa A. O `remove_participant` usa o mesmo motivo, porque a vaga foi liberada.

## R4. `remove_participant`

**Decisão:** ordem do contrato: `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`, `GAME_STARTED`, `CANNOT_REMOVE_SELF`, `NOT_PARTICIPANT`, `RECEIVER_LOCKED`. A passagem fica `removed`, `removal_reason = by_admin`, `left_at = now()` e `late_cancellation` nulo (RN58).

## R5. `leave_waitlist`

**Decisão:** bloqueia o jogo como as outras (`docs/contratos-api.md`, seção 1), só exige que a pessoa veja o jogo e tenha linha com `left_at` nulo. Não confere status nem tempo, porque o contrato não lista esses erros.

## R6. C03 já verde antes do código

O C03 usa só `join_waitlist`, `set_slot_limit` e `join_game`, da etapa A, e passou na primeira execução. Ele entra nesta etapa como regressão da RN53 e da RN54.
