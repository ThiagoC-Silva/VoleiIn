# T03 — Migração `autenticacao` e asserções

**Estado:** parcial (reaberta) · **Depende de:** T01

## Objetivo

Ligar `auth.users` a `pessoa` sem chave estrangeira (ver `docs/stack.md`, Autenticação). O perfil nasce com o mesmo id e com o nome dos metadados (`nome`, `full_name` ou `name`) **quando o e-mail fica confirmado**: no código do cadastro com senha, ou já no insert do primeiro acesso pelo Google. Nome vazio recusa o cadastro inteiro já no pedido (RN21). A troca de e-mail e a troca de senha apagam todos os aparelhos de push do titular (RNF07).

## Reaberta em 2026-10-20 — senha e Google

A primeira reabertura do dia, abaixo, decidiu que o perfil só nasce na confirmação, mas não chegou a ser implementada. Ela fica absorvida por esta, que acrescenta duas coisas:
- o nome vindo do Google;
- a revogação dos aparelhos também na troca de senha.

Ver as decisões no [README](README.md). A migração continua **editada no lugar**, porque ainda não foi ao remoto.

### O que falta

- [ ] Em `supabase/migrations/20261019194705_autenticacao.sql`:
  - auxiliar em `privado` que devolve o nome dos metadados: o primeiro preenchido entre `nome`, `full_name` e `name`, sem espaços nas pontas, ou `null`;
  - nova `privado.conferir_nome()`, gatilho `before insert on auth.users`: com a auxiliar nula, erro próprio do gatilho, e o cadastro é recusado no pedido. Vale para senha e para Google: conta Google sem nome também é recusada;
  - `privado.criar_pessoa()` usa a auxiliar e dispara em dois gatilhos:
    - `after insert ... when (new.email_confirmed_at is not null)`, para Google e Studio;
    - `after update of email_confirmed_at ... when (old.email_confirmed_at is null and new.email_confirmed_at is not null)`, para o código do cadastro e para o Google vinculado a um cadastro pendente;
  - `privado.apagar_dispositivos_na_troca()` passa a disparar em `after update of email, encrypted_password on auth.users`, `when (old.email is distinct from new.email or old.encrypted_password is distinct from new.encrypted_password)`;
  - `revoke execute` em todas as funções; comentários de acordo com `docs/stack.md`.
- [ ] `supabase/testes/autenticacao.sql`, refeito:
  - cadastro com senha não confirmado → existe `auth.users`, **não** existe `pessoa`;
  - confirmar (`email_confirmed_at = now()`) → `pessoa` com o mesmo id e o nome sem espaços;
  - insert sem nome, sem metadados ou só com espaços → recusado mesmo sem confirmação, conferindo o erro do gatilho novo em vez do `not null` de `pessoa.nome`;
  - metadados no formato do Google, inseridos já confirmados (`{"full_name": "Carla Souza", "name": "Carla Souza", "avatar_url": "https://…", "picture": "https://…"}`) → `pessoa` no insert, com `'Carla Souza'` e `avatar_url` nulo;
  - prioridade: `nome` vence `full_name`, e `name` vale quando `full_name` falta;
  - impostor: cadastro não confirmado com `{"nome": "Carla"}`, depois um `update` só que troca os metadados pelos do Google e preenche `email_confirmed_at` → `pessoa` com `'Carla Souza'`;
  - novo update de `email_confirmed_at` em quem já é confirmado, e a troca de e-mail, não criam segunda `pessoa`;
  - troca de senha (`encrypted_password` muda) apaga todos os aparelhos do titular; `update` que regrava o mesmo hash não apaga; aparelhos de outra pessoa ficam;
  - as asserções de `dispositivo_push` na troca de e-mail seguem como estão, com a Carla confirmada antes.
- [ ] `supabase/CLAUDE.md`, linha de `autenticacao.sql`: "criação do perfil na confirmação do e-mail e limpeza dos aparelhos na troca de e-mail e de senha".
- [ ] `supabase db reset` e as três suítes; atualizar a contagem de `autenticacao` abaixo.

## Primeira reabertura, em 2026-10-20 (absorvida)

A sonda da T02 mostrou que, com `enable_confirmations = false`, o Auth confirma o usuário já no pedido de código e o gatilho `after insert` cria `pessoa` antes de alguém digitar o código. Um e-mail digitado errado deixava conta confirmada e perfil órfão. Decidido: o perfil só nasce na confirmação (`docs/stack.md`, Autenticação). Os itens dela estão na lista acima.

## O que já existe

- `supabase/migrations/20261019194705_autenticacao.sql`, com duas funções:
  - `privado.criar_pessoa()`, gatilho `after insert`;
  - `privado.apagar_dispositivos_na_troca()`, gatilho `after update of email`, só quando o e-mail muda.

  As duas são `security definer`, com `search_path = ''` e sem `execute` para ninguém. Commitada em `69656e0`; comentários corrigidos em `51b3b35`. Aplicada **só no banco local**.
- `supabase/testes/autenticacao.sql` — 16 asserções, passando.

## O que falta (primeira rodada, feita)

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
docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql  # SUCESSO: N
```

`grep -rn "dupla\|duas confirmações\|dois endereços" supabase/migrations supabase/testes` não acha nada. O grep fica fora de `supabase/CLAUDE.md` porque a linha de `confirmar_presenca` ("duas confirmações simultâneas") trata de presença, não de e-mail.

## Commit

A migração e o teste já entraram em `69656e0` e `51b3b35`; a linha de comando, em `a28c2cf`. A reabertura vai junto com a da T02, em `Cria o perfil na confirmação do cadastro e aceita senha e Google`, porque um sem o outro não resolve: com o gatilho novo e a autoconfirmação ligada, o usuário já nasce confirmado e o perfil sai no insert de novo.
