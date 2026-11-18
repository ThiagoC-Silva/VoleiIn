# Implementation Plan: Conclusão, multas e rateio, etapa B (fatia 5)

**Branch**: `fatia-5/servidor-b` e `fatia-5/app-b` | **Date**: 2026-11-18 | **Spec**: [spec.md](./spec.md)

## Summary

Uma migração, `create_waive_penalty`, com `public.waive_penalty` (research R1 a R3). `complete_game` não muda: os cenários de faltas e isenção automática conferem o que a etapa A já faz. O seed ganha o jogo "Quinta com multas" (R4). No app (sessão 3): faltas na conclusão, isenção manual no Rateio e o histórico da pessoa no jogo (`docs/ui/telas.md`, seção 8).

## Technical Context

Igual ao da etapa A. Testes: T16, Z08 e Z09 em `completion_functions.test.sql`; R08, I01 a I12, F01, F02 e F05 a F14 em `completion_split.test.sql`; B06 em `base_security.test.sql`; C09 em `_tests/concurrency/completion_test.ts`.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa: a troca de nomes dos cenários I (R5) não muda nenhum resultado |
| II. Uma fatia por vez | Passa: troca de recebedor e Cobranças ficam na etapa C |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: o app chama `waive_penalty` e relê |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
