# Implementation Plan: Jogo e lista de presença, etapa C (fatia 4)

**Branch**: `fatia-4/servidor-c` e `fatia-4/app-c` | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

## Summary

Uma migração (`create_game_admin_functions`): `cancel_game`, `add_game_admin`, `remove_game_admin` e o novo corpo de `leave_group` e `remove_group_member`, com a auxiliar `private.leave_group_games` (research R1 a R4). Sem tabela, política ou Realtime novos. No app (sessão 3): cancelar pelo menu, a tela de admins (7.5), a sheet de saída bloqueada (7.8) e o telefone no perfil (6.9).

## Technical Context

Igual ao das etapas A e B. Testes: J14 a J21 em `games_functions.test.sql`, H01 a H10 em `groups_games.test.sql` (novo), W12 em `games_security.test.sql`, B06, e C07 e C16 no Deno.

## Constitution Check

| Princípio | Situação |
|-----------|----------|
| I. Documentos como fonte | Passa |
| II. Uma fatia por vez | Passa: troca de recebedor fica na fatia 5 |
| III. Testes antes | Passa: *commit* só de testes, com a saída da falha |
| IV. O servidor decide | Passa |
| V. Produção | Passa: com o ensaio, na sessão 4 |

## Complexity Tracking

Sem violações.
