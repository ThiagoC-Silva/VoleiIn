# Feature Specification: Conclusão, multas e rateio, etapa B (fatia 5)

**Feature Branch**: `fatia-5/servidor-b` (sessão 2) e `fatia-5/app-b` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-18

**Status**: Draft

**Input**: "Fatia 5, etapa B: faltas, multas e isenções."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 5, etapa B. Cenários: linha **B** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 13.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Faltas na conclusão (Priority: P1)

Ana, admin do jogo, marca quem faltou ao concluir. Quem saiu depois do início já vem marcado e pode ser desmarcado. Cada faltoso fica com uma multa igual à parte por vaga.

**Regras:** RF60 a RF63, RF69, RN47, RN63 a RN65. **Contrato:** `complete_game` (`docs/contratos-api.md`, seção 5), que já aplica as faltas desde a etapa A (research R1 de `specs/006-conclusao-etapa-a`). **Independent Test**: F01, F02, F05 a F08.

### User Story 2 - Isenção automática (Priority: P1)

Na conclusão, ficam só tantas multas de cancelamento fora do prazo quantas vagas ficaram ociosas no início, para os últimos a cancelar. Os demais são isentos e avisados.

**Regras:** RF56 a RF59, RF70, RN35, RN56 a RN62, RN65. **Independent Test**: T16, I01 a I12, F12 a F14, Z09.

### User Story 3 - Isenção manual (Priority: P1)

Ana isenta uma multa Pendente. O valor passa para Isento, sai dos totais e o participante é avisado.

**Regras:** RF64, RF72, RF104, RN66, RN93. **Contrato:** `waive_penalty` (`docs/contratos-api.md`, seção 5). **Independent Test**: F09 a F11, R08, Z08, C09.

### User Story 4 - Histórico da pessoa no jogo (Priority: P2, sessão 3)

Cada pessoa vê no detalhe do jogo concluído o que aconteceu com ela: faltou, cancelou no prazo, foi isenta ou tem multa.

**Telas:** `docs/ui/telas.md`, seção 8. **Independent Test**: S67, S69 (Isentos), S70, S71, L21.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | Os cenários de faltas, isenção automática e T16 rodam contra o `complete_game` da etapa A, sem mudar o contrato | 1, 2 | T16, I01 a I12, F01, F02, F05 a F08, F12 a F14, Z09 |
| FR-002 | `waive_penalty` com o contrato da seção 5 (research R1 a R3) | 3 | F09 a F11, R08, Z08 |
| FR-003 | Uma só transição em chamadas simultâneas de `waive_penalty` | 3 | C09 |
| FR-004 | Lista do B06 com `waive_penalty(uuid)` | Todas | B06 |
| FR-005 | Seed com uma multa Pendente e um valor Isento (`docs/setup.md`, seção 8; research R4) | 3, 4 | L21 (sessão 3) |
| FR-006 | Telas, textos e erros da etapa (sessão 3) | 1, 3, 4 | S67, S69 (Isentos), S70, S71, S75, S76, E15, L21 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha B passam, sem resultado esperado alterado.
- **SC-002**: C09 dá o resultado esperado em 50 de 50 repetições.
- **SC-003**: Do "Pronto quando" da fatia: o exemplo da seção 8 do `regras-negocio.md` (I01) isenta só a Ana; o recebedor nunca recebe multa (RF63, F06).

## Assumptions

- A etapa A está na `main` e na produção (PR #21 a #23; `docs/setup.md`, 9.9).
- **Fora da etapa:** troca de recebedor e aba Cobranças (etapa C); marcar como pago e o C09 com `mark_charge_paid` (fatia 6); avisos aos usuários (fatia 7).
