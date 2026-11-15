# Implementation Plan: Grupos (fatia 3)

**Branch**: `fatia-3/servidor` (sessão 2) e `fatia-3/app` (sessão 3) | **Date**: 2026-11-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-grupos/spec.md`

## Summary

A fatia 3 entrega os grupos: criar, convidar por código, pedir para entrar, aprovar, administrar os integrantes, editar e excluir, e o perfil de outra pessoa por contexto (`docs/plano-implementacao.md`, fatia 3).

No servidor, não há tabela nova: a fatia cria as quatro funções auxiliares de `private` (`is_group_member`, `is_group_admin`, `shares_context`, `has_pending_join_request`), concede a leitura de `groups`, `group_members` e `group_join_requests` e a leitura de `profiles` por contexto, cria as dez funções do `contratos-api.md` (seção 3), as quatro políticas novas do bucket `avatars` e a Edge Function `preview-invite` (`docs/rls-matriz.md`, fatia 3). O seed ganha os grupos Vôlei de Quinta e Vôlei de Domingo (`docs/setup.md`, seção 8).

No app, a feature `groups` ganha as camadas `domain`, `data` e `presentation`, com as telas da seção 6 do `docs/ui/telas.md`, seguindo os PNGs de `docs/ui/referencias/fatia-3/`.

## Technical Context

**Language/Version**: SQL (Postgres 17 do Supabase local); TypeScript no Deno 2.x (Edge Function e testes); Dart 3 e Flutter estável (sessão 3).

**Primary Dependencies**: as de `docs/arquitetura-app.md`, seção 3, e o `@supabase/supabase-js` 2 do `supabase/functions/deno.json`. Nenhum pacote novo no servidor. No app, o compartilhamento do convite usa o pacote previsto em `docs/arquitetura-app.md` (conferido na sessão 3).

**Storage**: Postgres do Supabase (tabelas da seção 4.2 do `docs/modelo-dados.md`) e a pasta `groups/` do bucket privado `avatars`.

**Testing**: pgTAP (`supabase test db`), Deno test contra o Supabase local (Storage, `preview-invite`, concorrência), `flutter_test` e `integration_test` no emulador (`docs/testes-referencia.md`, seção 11).

**Target Platform**: Android, API 29 a 36 (RNF01, RNF02).

**Project Type**: app móvel com backend gerenciado (`app/` e `supabase/`).

**Performance Goals**: os da RNF04. As funções auxiliares do RLS são `stable` e consultam por colunas indexadas (`docs/rls-matriz.md`, seção 6).

**Constraints**: o servidor decide e o app exibe; toda escrita em grupo passa pelas funções; sem Realtime nas tabelas de grupo (`docs/stacks.md`, 4.1); "sem acesso, sem pista" (`docs/contratos-api.md`, seção 1).

**Scale/Scope**: 10 funções SQL do app, 4 funções auxiliares, 1 Edge Function, 6 políticas de tabela, 4 de Storage, 8 rotas no app e os cenários G, K, A, Q, C, U, E, S e L da seção 11 do `docs/testes-referencia.md`.

## Constitution Check

*GATE: conferido antes da pesquisa e de novo depois do desenho.*

| Princípio | Situação |
|-----------|----------|
| I. Os documentos são a fonte da verdade | Passa. O spec e este plano citam `docs/`. As decisões técnicas do `research.md` não mudam regra nem contrato |
| II. Uma fatia por vez | Passa. Ficam de fora o link de convite (fatia 8), a RN16 e os efeitos da saída sobre jogos (fatia 4) e o texto final das notificações (fatia 7) |
| III. Testes antes do código | Passa. Em cada sessão, a fase de testes do `tasks.md` vem antes, com *commit* próprio e a saída da falha |
| IV. O servidor decide | Passa. Papéis, RN13, RN17, convite e contexto são do banco. O app confere o formato do código só para o aviso no campo (U08) |
| V. Produção é do responsável | Passa, com a atualização de 13/11/2026 (`docs/trabalho-com-agente.md`, seção 8): as migrações vão à produção na sessão 4, depois do ensaio de `docs/setup.md`, 9.2 |

Nenhuma violação a justificar. O princípio V da constituição ainda tem o texto anterior a 13/11/2026; a correção fica registrada no `tasks.md` para a sessão 4.

## Project Structure

### Documentation (this feature)

```text
specs/002-grupos/
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
├── config.toml                          # [functions.preview-invite] verify_jwt = false (research R5)
├── migrations/                          # 4 migrações novas (data-model.md)
├── seed.sql                             # Vôlei de Quinta e Vôlei de Domingo
├── tests/database/
│   ├── base_security.test.sql           # listas esperadas da fatia 3 (B03, B04, B06, B08, B10)
│   ├── groups_functions.test.sql        # G01 a G33
│   └── groups_security.test.sql         # K01 a K15
└── functions/
    ├── _shared/http.ts                  # respostas de sucesso e de erro (contratos-api.md, seção 1)
    ├── preview-invite/index.ts
    ├── preview-invite/index_test.ts     # Q01 a Q07
    └── _tests/
        ├── avatars_test.ts              # + A07 a A13
        └── concurrency/groups_test.ts   # C13 a C15

app/lib/features/groups/                 # sessão 3: domain, data, presentation
app/lib/features/people/ ou groups/      # perfil de outra pessoa (decidido na sessão 3)
app/test/, app/integration_test/         # U08, E13, E14, S18 a S35, L12 a L14
.github/workflows/ci.yml                 # testes da preview-invite no job database (research R6)
```

**Structure Decision**: a estrutura é a de `docs/arquitetura-app.md`, seções 2 e 14, e de `docs/setup.md`, seção 2. No servidor, as migrações seguem a ordem das dependências: funções auxiliares, RLS de tabela, funções do app, Storage.

## Complexity Tracking

Sem violações.
