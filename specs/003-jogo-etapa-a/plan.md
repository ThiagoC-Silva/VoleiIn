# Implementation Plan: Jogo e lista de presença, etapa A (fatia 4)

**Branch**: `fatia-4/servidor-a` (sessão 2) e `fatia-4/app-a` (sessão 3) | **Date**: 2026-11-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-jogo-etapa-a/spec.md`

## Summary

A etapa A da fatia 4 entrega criar, ver e editar o jogo, inclusive o limite de vagas, e entrar na lista e na espera, com Meus jogos, o detalhe e a chave Pix do recebedor (`docs/plano-implementacao.md`, fatia 4; linha A de `docs/testes-referencia.md`, seção 12).

No servidor, não há tabela nova. A etapa cria as duas funções auxiliares de `private` (`is_game_admin`, `can_view_game`), concede a leitura das cinco tabelas de jogo com as cinco políticas da `docs/rls-matriz.md` (fatia 4), põe `games`, `game_participants` e `game_waitlist` na publicação do Realtime e cria sete funções do app: `create_game`, `update_game`, `join_game`, `join_waitlist`, `set_slot_limit`, `get_profile_contact` e `get_game_groups` (`docs/contratos-api.md`, seção 4). O seed ganha os sete jogos da `docs/setup.md`, seção 8.

No app (sessão 3), a feature `games` ganha as camadas `domain`, `data` e `presentation`, com Meus jogos, Criar jogo, o detalhe, Editar jogo e os jogos no detalhe do grupo (`docs/ui/telas.md`, 7.1 a 7.4 e 7.6), seguindo os PNGs de `docs/ui/referencias/fatia-4/`.

## Technical Context

**Language/Version**: SQL (Postgres 17 do Supabase local); TypeScript no Deno 2.x (testes de concorrência); Dart 3 e Flutter estável (sessão 3).

**Primary Dependencies**: as de `docs/arquitetura-app.md`, seção 3, e o `@supabase/supabase-js` 2 do `supabase/functions/deno.json`. Nenhum pacote novo no servidor.

**Storage**: Postgres do Supabase (tabelas da seção 4.3 do `docs/modelo-dados.md`). Sem Storage nesta etapa.

**Testing**: pgTAP (`supabase test db`), Deno test contra o Supabase local (concorrência), `flutter_test` e `integration_test` no emulador (`docs/testes-referencia.md`, seção 12).

**Target Platform**: Android, API 29 a 36 (RNF01, RNF02).

**Project Type**: app móvel com backend gerenciado (`app/` e `supabase/`).

**Performance Goals**: RNF04 (lista em até 2 s, M06). As funções auxiliares do RLS são `stable` e consultam por colunas indexadas (`docs/rls-matriz.md`, fatia 4).

**Constraints**: o servidor decide status, vagas e prazos com o relógio dele (RN02); toda escrita em jogo passa pelas funções; cada função bloqueia a linha do jogo antes de tudo (`docs/contratos-api.md`, seção 1); "sem acesso, sem pista".

**Scale/Scope**: 7 funções SQL do app, 2 auxiliares de RLS, 5 políticas, 3 tabelas no Realtime, 4 rotas no app e os cenários J, O, T, C, W, U, S, L e M da linha A.

## Constitution Check

*GATE: conferido antes da pesquisa e de novo depois do desenho.*

| Princípio | Situação |
|-----------|----------|
| I. Os documentos são a fonte da verdade | Passa. O spec e este plano citam `docs/`. As decisões técnicas do `research.md` não mudam regra nem contrato |
| II. Uma fatia por vez | Passa. Ficam de fora as saídas, a remoção e a saída da espera (etapa B), admins, cancelamento, saída do grupo e telefone visível (etapa C), e o que é das fatias 5, 7 e 8 |
| III. Testes antes do código | Passa. Em cada sessão, a fase de testes do `tasks.md` vem antes, com *commit* próprio e a saída da falha |
| IV. O servidor decide | Passa. Status, vagas, prazos, acesso e chave Pix são do banco. O app só calcula a estimativa informativa (RF29, U11) e valida o formulário para avisar antes |
| V. Produção | Passa: as migrações vão à produção na sessão 4, depois do ensaio de `docs/setup.md`, 9.2 |

Nenhuma violação a justificar.

## Project Structure

### Documentation (this feature)

```text
specs/003-jogo-etapa-a/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── repositories.md   # sessão 3
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
supabase/
├── migrations/                          # 4 migrações novas (data-model.md)
├── seed.sql                             # os sete jogos da setup.md, seção 8
├── tests/database/
│   ├── base_security.test.sql           # listas esperadas da etapa A (B03, B04, B06)
│   ├── account_security.test.sql        # preparo: apaga os jogos do seed (research R6)
│   ├── groups_functions.test.sql        # idem
│   ├── groups_security.test.sql         # idem
│   ├── games_functions.test.sql         # J01 a J13
│   ├── games_list.test.sql              # O01 a O07, O20 a O23, T03 a T05
│   └── games_security.test.sql          # W01 a W11, W13 a W15
└── functions/_tests/concurrency/
    ├── support.ts                       # contas e grupo de teste da concorrência (research R7)
    └── games_test.ts                    # C01, C02, C04, C05

app/lib/features/games/                  # sessão 3: domain, data, presentation
app/test/, app/integration_test/         # U09 a U11, E15, S36 a S42, S50 a S53, L15
```

**Structure Decision**: a estrutura é a de `docs/arquitetura-app.md`, seções 2 e 14, e de `docs/setup.md`, seção 2. No servidor, as migrações seguem a ordem das dependências: funções auxiliares, RLS e Realtime, funções de jogo, funções de leitura.

## Complexity Tracking

Sem violações.
