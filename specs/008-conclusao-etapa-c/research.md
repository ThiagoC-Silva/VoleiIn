# Research: etapa C da fatia 5

## R1. Ordem das validações de `change_receiver`

**Decisão:** autenticação; existência (`NOT_FOUND`, pela `private.lock_game`); papel (`NOT_GAME_ADMIN`); estado do jogo (`GAME_CANCELLED` e, no jogo concluído, `RECEIVER_CHANGE_BLOCKED`); por último, a pessoa escolhida (`RECEIVER_UNCHANGED`, `RECEIVER_MUST_BE_PARTICIPANT` e `RECEIVER_NEEDS_PIX_KEY`). É a ordem da seção 1 do contrato: o bloqueio por valor Em análise é estado do jogo e vale para qualquer escolha, por isso vem antes dos dados de entrada. No app, o `RECEIVER_CHANGE_BLOCKED` fecha a sheet, e o `RECEIVER_NEEDS_PIX_KEY` a mantém aberta (S72, S73). Um `p_new_receiver_id` nulo responde `RECEIVER_MUST_BE_PARTICIPANT`, porque o contrato não lista `INVALID_INPUT`.

## R2. Quem está "na lista"

**Decisão:** a pessoa com passagem `active` no jogo (RN28), antes e depois da conclusão. Quem saiu após o início ocupa a vaga, mas não está mais na lista (V07). O faltoso marcado pelo admin continua `active` e pode ser o novo recebedor (V06).

## R3. Efeitos depois da conclusão

**Decisão:**
- O valor `pending` do novo recebedor: `status = waived`, `waived_at = now()`, `waive_reason = receiver_change`, `waived_by` = quem chama, e um `charge_events` de `pending` para `waived` com a nota `receiver_change` (Z15).
- Os outros valores `pending` do jogo: só `receiver_id` e `updated_at` mudam. Sem `charge_events`, porque o status não muda (contrato, seção 1: a tabela guarda transições de status); a troca fica em `receiver_changes`.
- O antigo recebedor sem valor ativo (`status <> waived`) ganha um `share` de `share_cents`, devido ao novo, ligado à passagem `active` dele, com um `charge_events` de nulo para `pending` e a nota `receiver_change`.
- `charges_transferred` conta os valores do segundo item; `charge_created` diz se o terceiro aconteceu.

## R4. Bloqueio

**Decisão:** `change_receiver` bloqueia o jogo (`lock_game`, seção 1 do contrato) e, no jogo concluído, os valores dele (`for update`, pela ordem do `id`), antes de procurar valores Em análise. Fica em fila com `complete_game` e `waive_penalty`, que bloqueiam o mesmo jogo, e prepara o C12 da fatia 6, em que `process-receipt` bloqueia o valor (RN32).

## R5. Notificações e auditoria

**Decisão:** `receiver_changed` a cada pessoa do conjunto {antigo recebedor, novo recebedor, pagadores com valor `pending` no jogo depois da troca}, uma vez por pessoa, exceto quem trocou, com o `data` da seção 5 do contrato. `charge_created` ao antigo recebedor quando ganha o `share`, mesmo que ele mesmo tenha trocado (Z15). Uma linha `receiver_changed` em `audit_log`, com `entity_type = game` e `data` `{ after_completion, charges_transferred, charge_created }`, sem dados pessoais (`docs/stacks.md`, 13.2): os ids das pessoas já ficam em `receiver_changes`.

## R6. Base dos testes

**Decisão:** a base da seção 7 nasce do `complete_game` sobre um jogo de R$ 100,00 e limite 5, com Bruno, Carla, P01 ("Davi") e Edu na lista e a falta do Edu, e o valor do Bruno passa a Pago direto, como `postgres` (como no F11). Edu e P01 ganham chave Pix só nos cenários da seção 7 ("Todos têm chave Pix"). "Zeca, fora da lista" é o Fábio. No Z12, o Bruno vira admin do Quinta antes da saída da Ana, porque ela é a única admin do grupo e receberia `LAST_ADMIN` (RN13), o que não é o que o cenário confere. Nenhum resultado muda.

## R7. Seed

**Decisão:** um jogo novo, "Quinta com troca" (`...0211`), de três dias antes, R$ 60,00 e 3 vagas, com Ana, Bruno e Carla na lista, como pede a linha 5 da tabela de dados do `setup.md` (seção 8, "Etapa C: troca de recebedor"). A Ana conclui pela `complete_game_core` e troca o recebedor para a Carla pela `change_receiver`: fica o `share` Isento da Carla, o do Bruno Pendente para a Carla e um `share` Pendente da Ana para a Carla. Na aba Cobranças, a Ana passa a ter um valor a pagar, e a Carla, valores a receber. O L22 continua preparando o próprio jogo (seção 13.6).

## R8. O que o antigo recebedor vê depois da troca (Y04)

**Decisão:** o valor Isento do novo recebedor continua devido ao antigo (`receiver_id`), porque a constraint `payer_id <> receiver_id` impede passá-lo ao próprio pagador e a RN31 só move os Pendentes. Pela política `charges_select_party` (`docs/rls-matriz.md`, fatia 5: "quem é o `receiver_id` de um valor o lê"), o antigo recebedor também o vê. O Y04 do `testes-referencia.md` lista o que a Ana vê (o Pago do Bruno e o próprio `share`) e o que não vê (Davi e Edu), sem citar o Isento da Carla; o teste confere os quatro e também o Isento, e o texto do Y04 ganhou essa linha, sem mudar nada do que já estava escrito.
