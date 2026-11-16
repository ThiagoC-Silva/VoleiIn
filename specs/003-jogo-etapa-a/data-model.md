# Data Model: Jogo e lista de presença, etapa A (fatia 4)

Nenhuma tabela, coluna ou enum novo. As tabelas `games`, `game_admins`, `game_participants`, `game_waitlist` e `game_limit_history` nasceram na fatia 1 (`docs/modelo-dados.md`, 4.3), com as *constraints*, os índices, a *trigger* do histórico de limite e a invariante de admin (RN25).

## Migrações desta etapa

| Migração | Conteúdo | Documento |
|----------|----------|-----------|
| `create_game_access_helpers` | `private.is_game_admin` e `private.can_view_game` | `docs/rls-matriz.md`, fatia 4 |
| `games_rls` | `select` de `authenticated` nas cinco tabelas, as cinco políticas e as três tabelas na publicação `supabase_realtime` | `docs/rls-matriz.md`, fatia 4; research R8 |
| `create_game_functions` | Auxiliares internas (research R2 e R5) e `create_game`, `update_game`, `join_game`, `join_waitlist`, `set_slot_limit` | `docs/contratos-api.md`, seção 4 |
| `create_game_read_functions` | `get_profile_contact` e `get_game_groups` | `docs/contratos-api.md`, seção 4 |

## Transições desta etapa

| De | Para | Quando | Regra |
|----|------|--------|-------|
| (criação) | `open` ou `confirmed` | `create_game`; `confirmed` com limite 1 | RN40 |
| `open` | `confirmed` | Entrada que enche a lista; redução do limite até o número de ocupadas | RN41 |
| `confirmed` | `open` | Aumento do limite | RN42 |

Passagem (`game_participants`): esta etapa só cria passagens `active` e, em `join_game`, preenche `cancellation_voided_at` das passagens `cancelled` anteriores da pessoa (RN56). Espera (`game_waitlist`): `join_waitlist` cria a linha ou limpa `left_at` e grava `joined_at = now()`; `join_game` preenche `left_at` (RN54).
