# Feature Specification: Pagamentos, etapa A (fatia 6)

**Feature Branch**: `fatia-6/servidor-a` (sessão 2) e `fatia-6/app-a` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-24

**Status**: Draft

**Input**: "Fatia 6, etapa A: valor a pagar com a chave Pix, marcar como pago e reverter."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 6, etapa A. Cenários: linha **A** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 14.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Marcar como pago (Priority: P1)

Ana, recebedora, recebe o Pix do Fábio e marca o valor dele como pago, sem comprovante. O Fábio é avisado.

**Regras:** RF84, RF97, RN84. **Contrato:** `mark_charge_paid` (`docs/contratos-api.md`, seção 6). **Independent Test**: PG01 a PG03, C09.

### User Story 2 - Reverter (Priority: P1)

Ana marcou por engano e devolve o valor a Pendente. Só ela pode, só o que foi marcado à mão, e nunca quando o pagador excluiu a conta ou virou o recebedor do jogo.

**Regras:** RF85, RF97, RN32, RN85, RN104. **Contrato:** `revert_charge`. **Independent Test**: PG04 a PG07.

### User Story 3 - Valor a pagar e ações no Rateio (Priority: P1, sessão 3)

O Fábio abre o valor a pagar, vê a chave Pix da Ana e a copia. A Ana marca e reverte pelo Rateio.

**Regras:** RF77, RF84, RF85, RN102. **Telas:** `docs/ui/telas.md`, seção 9. As leituras são `charges` pelo RLS da fatia 5 e `get_profile_contact` (`docs/contratos-api.md`, seção 9). **Independent Test**: S77 (sem comprovantes), S84 (sem **Conferir comprovante**), S85 (sem **Para conferir**), S88, S89, L23.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | `mark_charge_paid` com o contrato da seção 6 (research R1, R2 e R5) | 1 | PG01 a PG03 |
| FR-002 | `revert_charge` com o contrato da seção 6 (research R1 a R5) | 2 | PG04 a PG07 |
| FR-003 | Uma transição só entre a isenção e a marcação simultâneas (research R2) | 1 | C09 |
| FR-004 | Lista do B06 com `mark_charge_paid(uuid)` e `revert_charge(uuid)` | 1, 2 | B06 |
| FR-005 | Seed com um valor Pago marcado pela Ana (`docs/setup.md`, seção 8; research R6) | 3 | Sessão 3 |
| FR-006 | Telas, textos e erros da etapa (sessão 3) | 1, 2, 3 | S77, S84, S85, S88, S89, E15, L23 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha A passam, sem resultado esperado alterado.
- **SC-002**: O recebedor do jogo nunca volta a ter valor a pagar por uma reversão (PG07).

## Assumptions

- A fatia 5 está na `main` e na produção (`docs/setup.md`, 9.9 a 9.11).
- **Fora da etapa:** comprovantes (etapa B); `private.is_active_account`, a mudança de `require_uid` e a de `change_receiver` para conta excluída (etapa C); push dos eventos (fatia 7). O PG06 simula a conta excluída gravando `profiles.deleted_at`, coluna da fatia 1.
