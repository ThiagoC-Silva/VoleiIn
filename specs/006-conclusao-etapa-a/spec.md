# Feature Specification: Conclusão, multas e rateio, etapa A (fatia 5)

**Feature Branch**: `fatia-5/servidor-a` (sessão 2) e `fatia-5/app-a` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-18

**Status**: Draft

**Input**: "Fatia 5, etapa A: conclusão manual e automática e rateio."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 5, etapa A. Cenários: linha **A** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 13.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Concluir o jogo (Priority: P1)

Ana, admin do jogo, conclui o jogo a partir do fim. Antes de confirmar, vê a parte por vaga e o valor por conta do recebedor. Cada participante, menos o recebedor, fica com um valor Pendente devido ao recebedor.

**Regras:** RF40, RF41, RF67 a RF71, RN36, RN44, RN47, RN48, RN62, RN70 a RN75. **Contratos:** `preview_complete_game`, `complete_game` (`docs/contratos-api.md`, seção 5). **Telas:** `docs/ui/telas.md`, 8.1 e 8.2. **Independent Test**: T11, T12, R01 a R07, R09, R10, Z01 a Z04, Z06.

### User Story 2 - Conclusão automática (Priority: P1)

Uma hora depois do fim, o jogo não concluído é concluído sozinho, com a mesma lógica, sem mudar o total nem as faltas.

**Regras:** RF42, RN45, RN46, RN49. **Contrato:** `auto_complete_due_games` (`docs/contratos-api.md`, seção 7). **Independent Test**: T13 a T15, F03, F04, Z05, Z07, C08.

### User Story 3 - Ver o rateio (Priority: P2)

Cada pessoa vê só o próprio valor; o recebedor e os admins do jogo veem o rateio completo.

**Regras:** RF72 a RF74, RN76, RN32. **Banco:** políticas de `charges`, `charge_events` e `receiver_changes` (`docs/rls-matriz.md`, fatia 5). **Telas:** 8.1 e 8.3 (sessão 3). **Independent Test**: Y01 a Y03, Y05 a Y07.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | `complete_game` com a assinatura final e o passo a passo de `docs/modelo-dados.md`, seção 6, inteiro (research R1) | 1, 2 | T11, T12, Z01, Z02, Z04, Z06 |
| FR-002 | Rateio só com inteiros, cálculo em `bigint` (RN04, RN71) | 1 | R01 a R07, R09, R10 |
| FR-003 | `preview_complete_game` com os mesmos números, sem gravar | 1 | Z03 |
| FR-004 | `auto_complete_due_games` a cada 5 minutos, interna | 2 | T13 a T15, F03, F04, Z05, Z07, Y07 |
| FR-005 | Uma só conclusão em chamadas simultâneas | 2 | C08 |
| FR-006 | RLS de `charges`, `charge_events` e `receiver_changes` | 3 | Y01 a Y03, Y05, Y06, B03, B04 |
| FR-007 | Lista do B06 com `preview_complete_game` e `complete_game` | Todas | B06 |
| FR-008 | Seed com um jogo concluído e um aguardando conclusão (`docs/setup.md`, seção 8) | 1, 3 | L20 (sessão 3) |
| FR-009 | Telas, textos e erros da etapa (sessão 3) | Todas | U13, S61 a S66, S68, S69, S75, S76, E15, L20, M08 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha A passam, sem resultado esperado alterado.
- **SC-002**: C08 dá o resultado esperado em 50 de 50 repetições.
- **SC-003**: Do "Pronto quando" da fatia: R01 dá R$ 20,84 por vaga e R$ 229,24 a receber; a manual e a automática usam a mesma função (RN46); o recebedor nunca tem valor a pagar (RF71).

## Assumptions

- A fatia 4 está na `main` (PR #11 a #19).
- **Decisão de 18/11/2026 (responsável):** a isenção automática (RN62) entra já na etapa A, para a produção nunca cobrar multa que a regra isentaria (research R1).
- **Fora da etapa:** isenção manual (`waive_penalty`) e histórico da pessoa no jogo (etapa B); troca de recebedor e aba Cobranças (etapa C); pagamento (fatia 6); avisos aos usuários (fatia 7).
