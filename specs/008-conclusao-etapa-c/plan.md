# Implementation Plan: Conclusão, multas e rateio, etapa C (fatia 5)

**Branch**: `fatia-5/servidor-c` e `fatia-5/app-c` | **Date**: 2026-11-19 | **Spec**: [spec.md](./spec.md)

## Summary

Uma migração, `create_change_receiver`, com `public.change_receiver` (research R1 a R5). As políticas da etapa A não mudam: o Y04 confere o recorte do antigo recebedor. O seed ganha o jogo "Quinta com troca" (R7). No app (sessão 3): troca de recebedor no detalhe e a aba Cobranças (`docs/ui/telas.md`, seção 8).

## Technical Context

Igual ao da etapa A. Testes: Z10 a Z15 em `completion_functions.test.sql`; V01 a V11 em `completion_split.test.sql`; Y04 em `completion_security.test.sql`; B06 em `base_security.test.sql`. Sem cenário novo de concorrência: o C12 é da fatia 6.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa: as decisões da research completam o contrato sem mudar resultado esperado |
| II. Uma fatia por vez | Passa: comprovantes e o C12 ficam na fatia 6 |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: o app chama `change_receiver` e relê; os totais somam `charges` pelo RLS |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
