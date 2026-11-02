# T13 — Fechamento do passo

**Estado:** a fazer · **Depende de:** T01 a T12

## Objetivo

Conferir o passo inteiro, levar as migrações ao remoto, registrar o que não se descobre lendo o código e abrir o passo 5.

## O que já existe

- As sete migrações e as oito suítes SQL, mais `concorrencia.sh`.
- O modelo de entrada de `docs/progresso.md` (comentário no fim do arquivo).

## O que falta

- [ ] Conferência local: `supabase db reset`, as oito suítes e `concorrencia.sh`, com as contagens anotadas.
- [ ] Asserção de privilégio, numa das suítes: toda função de `public` criada no passo tem `execute` para `authenticated` e nenhuma para `anon` (`has_function_privilege`); nenhuma de `privado` criada no passo tem `execute` para `authenticated`.
- [ ] Conferir os códigos de recusa: a lista completa, por função, vai para `supabase/CLAUDE.md` (seção Funções), porque o app do passo 5 os traduz.
- [ ] `supabase/CLAUDE.md`, tabela de comandos: uma linha por suíte nova e uma para `concorrencia.sh`.
- [ ] Remoto: `supabase db push`; `supabase migration list` com os dois lados iguais; `get_advisors` de segurança pelo MCP do Supabase, sem alerta novo — o `function_search_path_mutable` de `tocar_atualizado_em` deve ter sumido.
- [ ] `docs/stack.md`: ajustar o que a implementação tiver mudado (funções, migrações).
- [ ] `docs/progresso.md`:
  - entrada "Passo 4 — Núcleo financeiro", com a data, no modelo do arquivo: o que foi entregue, arquivos, decisões de implementação (convenção de recusa, auxiliares em `privado`, migrações editadas no lugar até o `db push`, fila por local, como os testes simulam o tempo) e Aberto;
  - estado: passo 4 `feito`, passo atual 5.
- [ ] Marcar as tasks como `feito` no [README](README.md).

## Pronto quando

- Tudo verde no local; migrações iguais no local e no remoto; advisors sem alerta novo.
- `docs/progresso.md` aponta o passo 5 como atual.

## Commit

`Fecha o passo 4 — Núcleo financeiro`
