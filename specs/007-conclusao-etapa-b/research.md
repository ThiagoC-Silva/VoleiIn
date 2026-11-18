# Research: etapa B da fatia 5

## R1. Ordem das validações de `waive_penalty`

**Decisão:** autenticação; existência (`NOT_FOUND` se o valor não existe ou se quem chama não vê o jogo dele, pela `private.lock_game`); papel (`NOT_GAME_ADMIN`); tipo (`NOT_A_PENALTY`); status (`CHARGE_NOT_PENDING`). O tipo vem antes do status porque não muda nunca: um `share` sempre responde `NOT_A_PENALTY`, Pago ou não. Quem está no jogo sem ser admin recebe `NOT_GAME_ADMIN`, como no Z08, mesmo sem ler o valor pelo RLS: ele vê o jogo, então o código de papel não dá pista (`contratos-api.md`, seção 1).

## R2. Concorrência (C09)

**Decisão:** `waive_penalty` bloqueia primeiro o jogo do valor (`lock_game`, convenção da seção 1 do contrato) e só então lê o status do valor. Duas isenções simultâneas ficam em fila: a segunda vê `waived` e recebe `CHARGE_NOT_PENDING`. O C09 roda com Ana e Edu, os dois admins do jogo, em conexões separadas, 50 vezes.

## R3. Efeitos

**Decisão:** `status = waived`, `waived_at = now()`, `waive_reason = manual_waiver`, `waived_by` = quem chama, `updated_at = now()`; um `charge_events` de `pending` para `waived` com `actor_id`; `penalty_waived` ao pagador, com o `data` da seção 5 do contrato (`charge_id` e `reason` `manual_waiver`). Sem linha em `audit_log`: o contrato não a pede, e `charge_events` já guarda quem e quando (RN93).

## R4. Seed

**Decisão:** um jogo novo, "Quinta com multas" (`...0210`), de anteontem, R$ 40,00 e 4 vagas, com Ana e Carla na lista e Bruno com cancelamento fora do prazo. A Ana conclui com a Carla faltosa, pela `complete_game_core`: 2 vagas ociosas mantêm a multa do Bruno. Depois, a Ana isenta a multa do Bruno, com os mesmos efeitos da `waive_penalty`. Ficam uma `absence_penalty` Pendente (Carla) e uma `late_cancellation_penalty` Isenta (Bruno). O "Quinta concluído" (`...0208`) não muda, porque o `setup.md` (seção 8) e a etapa A o descrevem.

## R5. Cenários com nomes trocados

**Decisão:** nas tabelas I01 a I12, a recebedora é outra pessoa e "Ana" cancela (nota da seção 5). Nos testes, a base da seção 13 mantém a Ana como recebedora, e os papéis da tabela passam a Carla ("Ana"), Edu ("Bruno"), P01 ("Davi") e P02 ("Carla", quem entra). Os resultados não mudam: só os nomes.
