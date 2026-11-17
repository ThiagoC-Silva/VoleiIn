# Implementation Plan: Jogo e lista de presença, etapa B (fatia 4)

**Branch**: `fatia-4/servidor-b` (sessão 2) e `fatia-4/app-b` (sessão 3) | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

## Summary

Três funções novas do app, em uma migração (`create_game_exit_functions`): `leave_game`, `remove_participant` e `leave_waitlist` (`docs/contratos-api.md`, seção 4), reusando as auxiliares da etapa A (`lock_game`, `refresh_game_status`, `notify_waitlist`). Sem tabela, política ou Realtime novos. No app (sessão 3), as ações de sair, remover e sair da espera no detalhe do jogo (`docs/ui/telas.md`, 7.3; S43 a S47).

## Technical Context

Igual ao da etapa A (`specs/003-jogo-etapa-a/plan.md`). Testes: pgTAP em `games_list.test.sql` (O08 a O19, T01, T02, T06 a T10), B06 em `base_security.test.sql`, Deno em `_tests/concurrency/games_test.ts` (C03, C06).

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa: o spec cita `docs/`; o `research.md` só fixa ordem de erros e fronteiras já escritas |
| II. Uma fatia por vez | Passa: admins, cancelamento e saída do grupo ficam na etapa C |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa: saída, prazo, vaga e status no banco |
| V. Produção | Passa: migração na produção só na sessão 4, com o ensaio |

## Complexity Tracking

Sem violações.
