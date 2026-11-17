# Feature Specification: Jogo e lista de presença, etapa C (fatia 4)

**Feature Branch**: `fatia-4/servidor-c` (sessão 2) e `fatia-4/app-c` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-17

**Status**: Draft

**Input**: "Fatia 4, etapa C: admins do jogo, cancelamento, saída do grupo com jogos e telefone visível."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 4, etapa C. Cenários: linha **C** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 12.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cancelar o jogo (Priority: P1)

Ana, admin do jogo, cancela o jogo até a conclusão, inclusive em andamento. A lista e a espera são avisadas.

**Regras:** RF39, RF66, RN43, RN67, RN114. **Contrato:** `cancel_game`. **Telas:** `docs/ui/telas.md`, 7.3 (menu do admin; S54). **Independent Test**: J14 a J16, C07, L15 (o cancelamento).

### User Story 2 - Admins do jogo (Priority: P2)

Ana adiciona o Bruno como admin e deixa o papel; o jogo nunca fica sem admin.

**Regras:** RF34, RF35, RN25 a RN27. **Contratos:** `add_game_admin`, `remove_game_admin`. **Telas:** 7.5 (S55 a S57). **Independent Test**: J17 a J21, L18.

### User Story 3 - Sair do grupo com jogos (Priority: P1)

Quem sai ou é removido do grupo deixa as listas dos jogos não iniciados sem multa e perde o papel de admin; o recebedor e o único admin ficam bloqueados.

**Regras:** RF20 a RF22, RF102, RN14, RN16. **Contratos:** `leave_group`, `remove_group_member` (`docs/contratos-api.md`, seção 3). **Telas:** 7.8 (S48, S49). **Independent Test**: H01 a H10, C16, E16, L19.

### User Story 4 - Telefone visível (Priority: P3)

Quem compartilha contexto vê o telefone de quem o deixou visível (S58).

**Regras:** RF101, RN101. **Contrato:** `get_profile_contact` (etapa A). **Telas:** 6.9 (S58). **Independent Test**: W12, U12, S58.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | RF39, RN43, RN67, RN114 | 1 | J14 a J16, C07 |
| FR-002 | RF34, RF35, RN25 a RN27 | 2 | J17 a J21 |
| FR-003 | RN14 (saída do grupo retira das listas, sem multa, e do papel de admin) | 3 | H01 a H03, H07, H08, H10, C16 |
| FR-004 | RN16 (bloqueio de recebedor e único admin, com `detail.game_ids`) | 3 | H04 a H07, H09, E16 |
| FR-005 | RF101, RN101 | 4 | W12, U12, S58 |
| FR-006 | Evento `game_cancelled` (`docs/contratos-api.md`, seção 4) | 1 | J14 |
| FR-007 | Lista do B06 com as três funções novas (`docs/rls-matriz.md`, fatia 4) | Todas | B06 |
| FR-008 | Telas, textos e erros da etapa (sessão 3) | Todas | S48, S49, S54 a S58, E15, E16, L15, L18, L19, M07 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha C passam, sem resultado esperado alterado.
- **SC-002**: C07 e C16 dão o resultado esperado em 50 de 50 repetições.
- **SC-003**: Do "Pronto quando" da fatia: quem sai do grupo é retirado dos jogos não iniciados, e a saída é bloqueada para recebedor ou único admin (H01, H04, H05).

## Assumptions

- As etapas A e B estão na `main` (PR #11 a #17).
- `get_profile_contact` nasceu inteira na etapa A; o W12 entra aqui como regressão e passa antes do código (research R5).
- **Fora da fatia:** troca de recebedor (RF33, fatia 5), entrada pelo link (fatia 8).
