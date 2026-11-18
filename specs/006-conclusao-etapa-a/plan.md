# Implementation Plan: Conclusão, multas e rateio, etapa A (fatia 5)

**Branch**: `fatia-5/servidor-a` e `fatia-5/app-a` | **Date**: 2026-11-18 | **Spec**: [spec.md](./spec.md)

## Summary

Duas migrações. `completion_rls`: as auxiliares `private.is_game_receiver` e `private.can_view_charge`, o `select` de `authenticated` e as três políticas da fatia 5 (`docs/rls-matriz.md`). `create_completion_functions`: o núcleo `private.complete_game_core` (research R1 a R5), `preview_complete_game`, `complete_game`, `auto_complete_due_games` e o agendamento no `pg_cron` (R6, R7). O seed ganha dois jogos (R8). No app (sessão 3): o detalhe do jogo depois do fim e concluído, Concluir jogo e Rateio (`docs/ui/telas.md`, 8.1 a 8.3).

## Technical Context

Igual ao da fatia 4. Testes: T11 a T15, F03, F04 e Z01 a Z07 em `completion_functions.test.sql`; R01 a R07, R09 e R10 em `completion_split.test.sql`; Y01 a Y03 e Y05 a Y07 em `completion_security.test.sql`; B03, B04 e B06 em `base_security.test.sql`; C08 em `_tests/concurrency/completion_test.ts`.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa, com a decisão de R1 registrada em `testes-referencia.md` |
| II. Uma fatia por vez | Passa: isenção manual, troca de recebedor e Cobranças ficam nas etapas B e C |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: o app mostra o *preview*, sem calcular |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
