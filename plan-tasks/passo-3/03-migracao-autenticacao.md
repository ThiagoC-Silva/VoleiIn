# T03 — Migração `autenticacao` e asserções

**Estado:** parcial · **Depende de:** T01

## Objetivo

Ligar `auth.users` a `pessoa` sem chave estrangeira (ver `docs/stack.md`, Autenticação): o perfil nasce com o mesmo id e o nome dos metadados, e nome vazio recusa o cadastro inteiro (RN21). A troca de e-mail apaga todos os aparelhos de push do titular (RNF07).

## O que já existe

- `supabase/migrations/20261019194705_autenticacao.sql` — `privado.criar_pessoa()` (gatilho `after insert`) e `privado.apagar_dispositivos_na_troca()` (gatilho `after update of email`, só quando o e-mail muda), ambas `security definer`, `search_path = ''`, sem `execute` para ninguém. Aplicada **só no banco local**.
- `supabase/testes/autenticacao.sql` — 16 asserções, passando.

## O que falta

- [ ] Corrigir os comentários que ainda falam em confirmação dupla, contrariando `double_confirm_changes = false`:
  - na migração: "Com double_confirm_changes, o email só muda depois das duas confirmações";
  - no teste: "Com a confirmação dupla, o pedido de troca grava…" e a descrição `'troca confirmada nos dois endereços'`.

  Editar a migração é seguro **só porque ela ainda não foi ao remoto**. Depois do `db push` da T08, vale a regra de `supabase/CLAUDE.md`: corrige-se criando a próxima.
- [ ] Em `supabase/CLAUDE.md`, tabela de comandos: acrescentar a linha de `supabase/testes/autenticacao.sql`.
- [ ] `supabase db reset` e as três suítes.

## Pronto quando

```
supabase db reset
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql        # SUCESSO: 61
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql           # SUCESSO: 69
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql  # SUCESSO: 16
```

`grep -n "dupla\|duas confirmações\|dois endereços" supabase/` não acha nada.

## Commit

`Cria os gatilhos de perfil e de troca de e-mail do passo 3`
