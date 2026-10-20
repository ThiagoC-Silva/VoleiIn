# T03 — Migração `autenticacao` e asserções

**Estado:** parcial · **Depende de:** T01

## Objetivo

Ligar `auth.users` a `pessoa` sem chave estrangeira (ver `docs/stack.md`, Autenticação): o perfil nasce com o mesmo id e o nome dos metadados **quando o primeiro código é confirmado**, e nome vazio recusa o cadastro inteiro já no pedido (RN21). A troca de e-mail apaga todos os aparelhos de push do titular (RNF07).

## Reaberta em 2026-10-20

A sonda da T02 mostrou que, com `enable_confirmations = false`, o Auth confirma o usuário já no pedido de código e o gatilho `after insert` cria `pessoa` antes de alguém digitar o código. Um e-mail digitado errado deixava conta confirmada e perfil órfão. Decidido: o perfil só nasce na confirmação (`docs/stack.md`, Autenticação). A migração é **editada no lugar**, como na correção de comentários abaixo, porque ainda não foi ao remoto.

### O que falta (reabertura)

- [ ] Em `supabase/migrations/20261019194705_autenticacao.sql`:
  - nova `privado.conferir_nome()`, gatilho `before insert on auth.users`: nome dos metadados sem espaços nas pontas, vazio ou ausente → erro, e o cadastro é recusado no pedido;
  - `privado.criar_pessoa()` passa a disparar em dois gatilhos: `after insert ... when (new.email_confirmed_at is not null)` (usuário inserido já confirmado, como pelo Studio) e `after update of email_confirmed_at ... when (old.email_confirmed_at is null and new.email_confirmed_at is not null)`;
  - `revoke execute` também na função nova; comentários de acordo.
- [ ] `supabase/testes/autenticacao.sql`, refeito para o novo momento:
  - insert não confirmado com nome → existe `auth.users`, **não** existe `pessoa`;
  - confirmar (`email_confirmed_at = now()`) → `pessoa` com o mesmo id e o nome sem espaços;
  - insert sem nome, sem metadados ou só com espaços → recusado mesmo sem confirmação (manter as três asserções atuais, conferindo o erro do gatilho novo em vez do `not null` de `pessoa.nome`);
  - insert já confirmado → `pessoa` criada no insert;
  - novo update de `email_confirmed_at` em quem já é confirmado, e a troca de e-mail, não criam segunda `pessoa`;
  - as asserções de `dispositivo_push` na troca seguem como estão, com a Carla confirmada antes.
- [ ] `supabase db reset` e as três suítes; atualizar a contagem de `autenticacao` abaixo.

## O que já existe

- `supabase/migrations/20261019194705_autenticacao.sql` — `privado.criar_pessoa()` (gatilho `after insert`) e `privado.apagar_dispositivos_na_troca()` (gatilho `after update of email`, só quando o e-mail muda), ambas `security definer`, `search_path = ''`, sem `execute` para ninguém. Commitada em `69656e0`; comentários corrigidos em `51b3b35`. Aplicada **só no banco local**.
- `supabase/testes/autenticacao.sql` — 16 asserções, passando.

## O que falta

- [x] Corrigir os comentários que ainda falam em confirmação dupla, contrariando `double_confirm_changes = false`:
  - na migração: "Com double_confirm_changes, o email só muda depois das duas confirmações";
  - no teste: "Com a confirmação dupla, o pedido de troca grava…" e a descrição `'troca confirmada nos dois endereços'`.

  Editar a migração é seguro **só porque ela ainda não foi ao remoto**. Depois do `db push` da T08, vale a regra de `supabase/CLAUDE.md`: corrige-se criando a próxima.
- [x] Em `supabase/CLAUDE.md`, tabela de comandos: acrescentar a linha de `supabase/testes/autenticacao.sql`.
- [x] `supabase db reset` e as três suítes.

## Pronto quando

```
supabase db reset
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql        # SUCESSO: 61
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql           # SUCESSO: 69
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql  # SUCESSO: 16
```

`grep -rn "dupla\|duas confirmações\|dois endereços" supabase/migrations supabase/testes` não acha nada. O grep fica fora de `supabase/CLAUDE.md` porque a linha de `confirmar_presenca` ("duas confirmações simultâneas") trata de presença, não de e-mail.

## Commit

A migração e o teste já entraram em `69656e0` e `51b3b35`; a linha de comando, em `a28c2cf`. A reabertura vai em: `Cria o perfil só quando o primeiro código é confirmado`, junto com o `enable_confirmations = true` da T02, porque um sem o outro não resolve: com o gatilho novo e a autoconfirmação ligada, o usuário já nasce confirmado e o perfil sai no insert de novo.
