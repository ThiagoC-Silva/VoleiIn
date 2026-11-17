# Feature Specification: Jogo e lista de presença, etapa B (fatia 4)

**Feature Branch**: `fatia-4/servidor-b` (sessão 2) e `fatia-4/app-b` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-17

**Status**: Draft

**Input**: "Fatia 4, etapa B: saídas, vagas, lista de espera e concorrência."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 4, etapa B. Cenários: linha **B** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 12.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sair da lista (Priority: P1)

Bruno sai da lista antes do prazo, depois do prazo ou depois do início. A vaga é liberada só antes do início, e a espera é avisada.

**Regras:** RF50, RN03, RN29, RN35, RN42, RN56, RN57, RN60, RN61. **Contrato:** `leave_game` (`docs/contratos-api.md`, seção 4). **Telas:** `docs/ui/telas.md`, 7.3 (S43 a S45, sessão 3).

**Independent Test**: O08 a O14, T01, T02, T06 a T10, C06.

**Acceptance Scenarios**: os de O08 a O14 e T01, T02, T06 a T10 (`docs/testes-referencia.md`, 12.2 e seção 3).

### User Story 2 - Sair e voltar à espera (Priority: P1)

Edu sai da espera e volta para o fim da ordem; quando abre uma vaga, entra na lista e sai da espera. A espera não dá prioridade.

**Regras:** RF49, RN51, RN53, RN54. **Contrato:** `leave_waitlist`. **Telas:** 7.3 (S46, S47).

**Independent Test**: O15, O16, C03.

### User Story 3 - Remover um participante (Priority: P2)

Ana, admin do jogo, remove o Bruno da lista antes do início, sem multa.

**Regras:** RF54, RF59, RN29, RN58. **Contrato:** `remove_participant`. **Telas:** 7.3 (sessão 3).

**Independent Test**: O17 a O19.

### Edge Cases

Decididos no documento citado: prazo em `now()` é no prazo (T01); início em `now()` é depois do início, mesmo com o prazo também em `now()` (T07, T08); fim em `now()` trava a lista (T10, RN57); o recebedor não sai nem é removido (O11, O19, RN29); quem volta depois de cancelar fora do prazo anula o cancelamento anterior (O14, RN56).

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | RF50, RN03, RN57, RN60, RN61 | 1 | O08 a O10, O12, T01, T02, T06 a T10 |
| FR-002 | RN29 (recebedor travado) | 1, 3 | O11, O19 |
| FR-003 | RN56 (cancelar e voltar anula) | 1 | O14 |
| FR-004 | RF49, RN51, RN54 (saída da espera e volta ao fim) | 2 | O15, O16 |
| FR-005 | RN53 (disputa justa nas saídas e na espera) | 1, 2 | C03, C06 |
| FR-006 | RF54, RF59, RN58 | 3 | O17, O18 |
| FR-007 | Eventos `waitlist_slot_opened` (`reason: slot_freed`) e `removed_from_game` (`docs/contratos-api.md`, seção 4) | 1, 3 | O08, O17 |
| FR-008 | Lista do B06 com as três funções da etapa (`docs/rls-matriz.md`, fatia 4) | Todas | B06 |
| FR-009 | Telas, textos e erros da etapa (sessão 3) | Todas | S43 a S47, E15, L16, L17 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha B passam, sem resultado esperado alterado.
- **SC-002**: C03 e C06 dão o resultado esperado em 50 de 50 repetições.
- **SC-003**: Do "Pronto quando" da fatia: cancelar e voltar anula o cancelamento (O14) e o status passa entre Aberto e Confirmado nas saídas (O08, O17, C06).

## Assumptions

- A etapa A está na `main` (PR #11 a #15). Nenhuma tabela, política ou publicação do Realtime nova: as três funções escrevem em tabelas que já estão no Realtime.
- `leave_game` segue a ordem de erros da assinatura do contrato: `NOT_FOUND`, `GAME_NOT_OPEN`, `NOT_PARTICIPANT`, `RECEIVER_LOCKED`, `LIST_LOCKED` (research R1).
- **Fora desta etapa:** admins do jogo, cancelamento, saída do grupo com jogos, telefone visível, C07 e C16 (etapa C); multas (fatia 5).
