# T02 — Migrações de ajuste

**Estado:** a fazer · **Depende de:** T01

## Objetivo

Abrir o passo com as duas migrações de ajuste previstas em `docs/stack.md` (Ordem de implementação, passo 4): uma corrige duas funções existentes, a outra traz a estrutura que as decisões de 2026-11-01 pedem.

## O que já existe

- `privado.encerramento_previsto` em `20261019183743_rls.sql`, declarada `immutable`; a soma de `timestamptz` com intervalo é `stable` no Postgres.
- `tocar_atualizado_em()` em `20261019172256_tabelas.sql`, sem `search_path` fixo — o verificador de segurança do Supabase acusa `function_search_path_mutable`.
- `jogo` sem `cancelamento_livre_ate`; `cobranca` sem nada que impeça `devedor_id = credor_id`.
- `supabase/testes/schema.sql` com 65 asserções.

## O que falta

- [ ] `supabase migration new ajustes_funcoes`:
  - `create or replace function privado.encerramento_previsto(...)` com `stable` no lugar de `immutable`, mesmo corpo e mesmo `search_path`;
  - `alter function tocar_atualizado_em() set search_path = ''` — o corpo só usa `now()`, que está em `pg_catalog`.
- [ ] `supabase migration new ajustes_schema`:
  - `alter table jogo add column cancelamento_livre_ate timestamptz` — anulável, sem default; comentário apontando RN02 e RN20;
  - `alter table cobranca add constraint cobranca_devedor_nao_e_credor check (devedor_id <> credor_id)` — RN07: o recebedor que joga não tem cobrança.
- [ ] `supabase/testes/schema.sql`:
  - a coluna existe, é `timestamptz` e anulável;
  - cobrança com devedor igual ao credor é recusada com `23514` e `cobranca_devedor_nao_e_credor`;
  - `privado.encerramento_previsto` tem `provolatile = 's'`;
  - `tocar_atualizado_em` tem `search_path` em `proconfig`.
- [ ] `supabase db reset` e as três suítes.

## Pronto quando

```
supabase db reset
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql        # SUCESSO: 65 + as novas
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql           # SUCESSO: 69
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql  # SUCESSO: 39
```

## Commit

`Ajusta duas funções e acrescenta o campo da remarcação e o check do recebedor`
