# Feature Specification: Pagamentos, etapa B (fatia 6)

**Feature Branch**: `fatia-6/servidor-b` (sessão 2) e `fatia-6/app-b` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-25

**Status**: Draft

**Input**: "Fatia 6, etapa B: envio, leitura e análise de comprovantes."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto. Escopo: `docs/plano-implementacao.md`, Fatia 6, etapa B. Cenários: linha **B** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 14. Leitura: `docs/comprovantes-ia.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enviar e ter o comprovante lido (Priority: P1)

O Fábio paga a Ana por Pix e envia o comprovante. O servidor lê o arquivo pela Claude API, confere a RN88 e aprova na hora, manda para análise ou recusa por ID repetido.

**Regras:** RF78 a RF83, RF104, RN32, RN80, RN81, RN86 a RN89. **Contratos:** `process-receipt` (`docs/contratos-api.md`, seção 8) e `record_receipt` (seção 7). **Independent Test**: CP01 a CP24, PR01 a PR10, NM01 a NM05, CF01 a CF26, C10 a C12.

### User Story 2 - Conferir o comprovante Em análise (Priority: P1)

A Ana abre o comprovante Em análise, vê o que foi lido e aprova, ou recusa com uma observação.

**Regras:** RF83, RN82, RN83, RN90. **Contrato:** `review_receipt` (seção 6). **Independent Test**: RV01 a RV06, C18.

### User Story 3 - Só o pagador e o recebedor veem o comprovante (Priority: P1)

O comprovante e o arquivo são só do pagador e do recebedor gravado nele. Ninguém escreve direto em `receipts`, nem envia arquivo fora do formato ou para valor que não está Pendente.

**Regras:** RF87, RN86, RN87. **RLS:** `docs/rls-matriz.md`, fatia 6, linhas da etapa B. **Independent Test**: RS01 a RS09 (RS09 sem as funções da etapa C), B03, B04, B06, B10.

### User Story 4 - Telas de comprovante (Priority: P1, sessão 3)

Enviar comprovante, Comprovante (pagador e recebedor), **Conferir comprovante** no Rateio e **Para conferir** em Cobranças. **Telas:** `docs/ui/telas.md`, seção 9. **Independent Test**: U14, S77 a S83, S84 (**Conferir comprovante**), S85 (**Para conferir**), S88, S89, E15, L24, L25.

## Requirements *(mandatory)*

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | `record_receipt` com o contrato da seção 7 e a conferência do `comprovantes-ia.md` (seção 5) (research R1 a R4) | 1 | CP01 a CP24, C10 a C12 |
| FR-002 | `review_receipt` com o contrato da seção 6 (research R5) | 2 | RV01 a RV06, C18 |
| FR-003 | Leitura de `receipts`, bucket `receipts` e auxiliares da fatia 6 (research R6) | 3 | RS01 a RS09, B03, B04, B06, B10 |
| FR-004 | Edge Function `process-receipt`, com o prompt, o schema, a normalização, o tempo limite e as tentativas do `comprovantes-ia.md` (research R7 a R9) | 1 | PR01 a PR10, NM01 a NM05 |
| FR-005 | Conjunto fixo CF01 a CF26, gerado por `scripts/receipt-fixtures.py`, e os dois jeitos de rodar (research R10) | 1 | CF01 a CF26 |
| FR-006 | Medição dos três modelos com a API real e escolha do `RECEIPT_MODEL` (`comprovantes-ia.md`, seção 9; research R11) | 1 | CF01 a CF26 (API real) |
| FR-007 | Seed com o jogo de comprovantes (`docs/setup.md`, seção 8; research R12) | 4 | Sessão 3 |
| FR-008 | Telas, textos e erros da etapa (sessão 3) | 4 | U14, S77 a S85, S88, S89, E15, L24, L25 |

## Success Criteria *(mandatory)*

- **SC-001**: Todos os cenários automáticos de servidor da linha B passam, sem resultado esperado alterado.
- **SC-002**: Nenhum exemplo de CF11 a CF24 é aprovado, nem com a API simulada nem com o modelo escolhido, em três execuções seguidas (`comprovantes-ia.md`, seção 7).
- **SC-003**: A leitura termina em até 30 s (RNF04): a chamada à API, com repetição e contagem, para em 25 s (PR07).

## Assumptions

- A etapa A está na `main` e na produção (`docs/setup.md`, 9.12). A chave `voleiin-local` está em `supabase/functions/.env`, e o alerta de US$ 4 está ativo (`setup.md`, 6.3, feito em 25/11/2026).
- **Fora da etapa:** `storage-cleanup`, `list_storage_cleanup`, `mark_receipts_file_deleted`, `delete_account`, a mudança de `private.require_uid` e as políticas de conta excluída (etapa C); push dos eventos (fatia 7). `private.is_active_account` entra aqui, porque o RLS do bucket `receipts` a usa (`rls-matriz.md`, fatia 6).
