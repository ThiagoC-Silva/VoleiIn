# T08.4 — Aplicar as migrações no remoto

**Estado:** feito · **Depende de:** T08.3

## Objetivo

Levar as cinco migrações do passo 1 ao 3 ao remoto. Daqui em diante, nenhuma delas pode mais ser editada (`supabase/CLAUDE.md`, Migrações).

## O que já existe

- `enums`, `tabelas`, `indices`, `rls`, `autenticacao` em `supabase/migrations/`. Os comentários da `autenticacao` já foram corrigidos (`51b3b35`).
- `supabase db reset` passa no local, e as suítes `schema` (61), `rls` (69) e `autenticacao` (36) também.
- A `autenticacao` cria gatilhos em `auth.users`.

## O que falta

- [ ] Antes do push, `supabase db reset` e as três suítes no local, para aplicar no remoto exatamente o que passa aqui.
- [ ] **[Thiago]** `! supabase db push --dry-run`: lista as cinco migrações e nada mais.
- [ ] **[Thiago]** `! supabase db push`, sem `--include-seed` (README, "A decidir").
- [ ] Se uma migração falhar no remoto, **parar**: não editar a migração; levar o erro ao Thiago.
- [ ] `supabase migration list` mostra as cinco nos dois lados.
- [ ] **[Thiago]** Conferência no editor SQL do painel, com a consulta que o Claude preparar:
  - as treze tabelas de `public`, todas com política de linha ligada;
  - o schema `privado` com as auxiliares, e fora dos schemas expostos da API;
  - os gatilhos da `autenticacao` em `auth.users`;
  - nenhum privilégio de `anon` nas tabelas de `public`. Se houver, a opção de exposição automática da T08.3 venceu a revogação: parar e decidir.

## Resultado

Feito em 2026-10-27.

- Antes do push: `supabase db reset` passou no local, e as suítes `schema` (61), `rls` (69) e `autenticacao` (36) também.
- `supabase db push --dry-run` listou as cinco migrações, sem seed e sem papéis. O `supabase db push --yes` as aplicou sem erro, sem `--include-seed`. O seed não foi ao remoto.
- `supabase migration list` mostra as cinco versões nos dois lados. O push não mudou nada versionado.
- Conferência no editor SQL do painel, com sete itens, todos iguais ao local: 13 tabelas em `public`, todas com RLS ligada; as 10 auxiliares em `privado`; os 4 gatilhos em `auth.users`; nenhum privilégio de `anon` em tabela ou função de `public`; `anon` sem uso do schema `privado`. A consulta pede `has_schema_privilege` só para `anon`: `authenticated` precisa do uso de `privado`, porque as políticas chamam as auxiliares como o próprio usuário.
- Pela API, com a chave pública: `privado` devolve `PGRST106` ("Only the following schemas are exposed: public, graphql_public"), e `public.pessoa` devolve `42501`. A exposição automática da T08.3 não desfez a revogação.

## Pronto quando

`supabase migration list` mostra as cinco migrações nos dois lados, e a conferência no painel bate com o local.

## Commit

`Aplica as migrações no projeto remoto`, com o registro desta task e o que o `push` tiver mudado de versionado (nada esperado).
