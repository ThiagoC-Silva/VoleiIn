# Feature Specification: Conclusão, multas e rateio, etapa C (fatia 5)

**Feature Branch**: `fatia-5/servidor-c` (sessão 2) e `fatia-5/app-c` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-19

**Status**: Draft

**Input**: "Fatia 5, etapa C: troca de recebedor e totais; aba Cobranças."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 5, etapa C. Cenários: linha **C** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 13.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Troca antes da conclusão (Priority: P1)

Ana, admin e recebedora, passa o recebimento para a Carla antes do jogo. Só o recebedor muda; na conclusão, os valores são devidos à Carla, e a Ana paga a própria parte.

**Regras:** RF33, RF97, RN28 a RN30, RN115. **Contrato:** `change_receiver` (`docs/contratos-api.md`, seção 5). **Independent Test**: Z10 a Z14, V08 a V11.

### User Story 2 - Troca depois da conclusão (Priority: P1)

Ana troca o recebedor de um jogo concluído. Os Pagos ficam com ela, os Pendentes passam ao novo, o valor do novo recebedor fica Isento e a Ana ganha um `share` Pendente, salvo se já tiver um valor ativo no jogo.

**Regras:** RF33, RF97, RN31, RN32, RN94, RN115. **Independent Test**: V01 a V07, Z15, Y04.

### User Story 3 - Totais e aba Cobranças (Priority: P1, sessão 3)

Cada pessoa vê o total que deve e o que tem a receber, somando todos os jogos, com o detalhe por jogo.

**Regras:** RF75, RF76, RN76. **Telas:** `docs/ui/telas.md`, seção 8. Os totais são leituras de `charges` pelo RLS da etapa A (`docs/contratos-api.md`, seção 9). **Independent Test**: S72 a S74, L22.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | `change_receiver` com o contrato da seção 5 (research R1 a R5) | 1, 2 | V01 a V11, Z10, Z13 a Z15 |
| FR-002 | As saídas da fatia 4 seguem o recebedor gravado depois da troca, sem mudança nelas | 1 | Z11, Z12 |
| FR-003 | O RLS da etapa A dá ao antigo recebedor só os valores devidos a ele e o próprio, sem mudança nas políticas | 2 | Y04 |
| FR-004 | Lista do B06 com `change_receiver(uuid, uuid)` | Todas | B06 |
| FR-005 | Telas, textos e erros da etapa (sessão 3) | 1, 2, 3 | S72 a S76, E15, L22 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha C passam, sem resultado esperado alterado.
- **SC-002**: Do "Pronto quando" da fatia: os testes de troca de recebedor passam; o recebedor nunca tem valor a pagar (notas de "Em todos" da seção 7); o antigo recebedor sem ser admin vê só o que é dele (RN76, Y04).

## Assumptions

- As etapas A e B estão na `main` e na produção (PR #21 a #26; `docs/setup.md`, 9.9 e 9.10).
- **Fora da etapa:** C12 (`change_receiver` com `process-receipt`, fatia 6); pagar, comprovante e marcar como pago (fatia 6); avisos aos usuários (fatia 7).
