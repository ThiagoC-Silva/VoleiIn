# Data Model: Grupos (fatia 3)

Nenhuma tabela, coluna ou enum novo. As tabelas `groups`, `group_members` e `group_join_requests`, a *trigger* da RN13 e o bucket `avatars` nasceram na fatia 1 (`docs/modelo-dados.md`, 4.2 e seção 7). Esta fatia acrescenta só funções, privilégios e políticas.

## Migrações

| Ordem | Migração | Conteúdo | Documento |
|-------|----------|----------|-----------|
| 1 | `create_group_access_helpers` | `private.is_group_member`, `private.is_group_admin`, `private.shares_context`, `private.has_pending_join_request`, com `execute` para `authenticated`; `private.generate_invite_code()`, sem `execute` para o app | `docs/rls-matriz.md`, fatia 3; research R1 |
| 2 | `groups_rls` | `grant select` nas três tabelas e as seis políticas de tabela | `docs/rls-matriz.md`, fatia 3 |
| 3 | `create_group_functions` | As dez funções do app, com `revoke ... from public, anon` e `grant ... to authenticated` | `docs/contratos-api.md`, seção 3; research R2 |
| 4 | `avatars_group_policies` | As quatro políticas de `storage.objects` da pasta `groups/` e da leitura das fotos de perfil por contexto | `docs/rls-matriz.md`, fatia 3 |

## Estados da solicitação

`pending` → `approved` ou `rejected` (`decide_join_request`, com `decided_by`); `pending` → `cancelled` (`archive_group`, com `decided_by` nulo). Depois de `rejected`, a pessoa pode criar outra (RN12).

## Seed

`docs/setup.md`, seção 8: Vôlei de Quinta (`...0101`, `VoleiQuinta1`, Ana admin, Bruno e Carla) e Vôlei de Domingo (`...0102`, `VoleiDomingo`, Bruno admin, solicitação pendente do Diego). Sem foto.
