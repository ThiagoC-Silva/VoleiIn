# T13 — Fechamento do passo

**Estado:** feito · **Depende de:** T01 a T12

## Objetivo

Conferir o passo inteiro, levar as migrações ao remoto, registrar o que não se descobre lendo o código e abrir o passo 5.

## O que já existe

- As sete migrações e as oito suítes SQL, mais `concorrencia.sh`.
- O modelo de entrada de `docs/progresso.md` (comentário no fim do arquivo).

## O que falta

- [x] Conferência local: `supabase db reset`, as oito suítes e `concorrencia.sh`, com as contagens anotadas.
- [x] Asserção de privilégio, numa das suítes: toda função de `public` criada no passo tem `execute` para `authenticated` e nenhuma para `anon` (`has_function_privilege`); nenhuma de `privado` criada no passo tem `execute` para `authenticated`.
- [x] Conferir os códigos de recusa: a lista completa, por função, vai para `supabase/CLAUDE.md` (seção Funções), porque o app do passo 5 os traduz.
- [x] `supabase/CLAUDE.md`, tabela de comandos: uma linha por suíte nova e uma para `concorrencia.sh`.
- [x] Remoto: `supabase db push`; `supabase migration list` com os dois lados iguais; `get_advisors` de segurança pelo MCP do Supabase, sem alerta novo — o `function_search_path_mutable` de `tocar_atualizado_em` deve ter sumido.
- [x] `docs/stack.md`: ajustar o que a implementação tiver mudado (funções, migrações).
- [x] `docs/progresso.md`:
  - entrada "Passo 4 — Núcleo financeiro", com a data, no modelo do arquivo: o que foi entregue, arquivos, decisões de implementação (convenção de recusa, auxiliares em `privado`, migrações editadas no lugar até o `db push`, fila por local, como os testes simulam o tempo) e Aberto;
  - estado: passo 4 `feito`, passo atual 5.
- [x] Marcar as tasks como `feito` no [README](README.md).

## Resultado

- **Local:** `supabase db reset`; `schema` 70, `rls` 74, `autenticacao` 39, `rpc_grupo` 63, `rpc_jogo` 164, `rpc_presenca` 126, `rpc_cobranca` 42 e `rpc_conta` 21 asserções; `concorrencia.sh` com 3 cenários, e as suítes verdes de novo depois dele.
- **Privilégio, pelo catálogo, em `rls.sql`:** toda função de `public`, fora as de gatilho, é executada por `authenticated` e não por `anon`, e é `security definer` com `search_path` vazio. As de gatilho não são executadas pelo app. Em `privado`, `authenticated` executa só as cinco auxiliares das políticas, `anon` nada, e toda função tem `search_path` vazio. É uma varredura, e não uma lista, para pegar as funções dos próximos passos.
- **Códigos de recusa:** a lista por função e o que cada código quer dizer estão em `supabase/CLAUDE.md`, seção Funções, conferidos contra os `raise` das migrações.
- **Remoto:** o projeto estava pausado por inatividade e foi reativado pelo MCP. A pasta foi vinculada com `supabase link` (o login foi do usuário). O `--dry-run` listou só as sete migrações do passo, e o push foi rodado pelo usuário, porque o controle de permissões da sessão barrou a escrita no remoto. `supabase migration list --linked` bate nos treze arquivos. O catálogo do remoto confere com o local: 17 RPCs dentro da regra, as cinco auxiliares de `privado`, a coluna `cancelamento_livre_ate` e o `check` `cobranca_devedor_nao_e_credor`.
- **Verificador de segurança:** o `function_search_path_mutable` de `tocar_atualizado_em` sumiu. O `authenticated_security_definer_function_executable`, que antes acusava só a `listar_participantes`, passou a acusar as 17 RPCs. Não é um tipo novo de alerta, e é o desenho: toda mutação passa por função `security definer` que confere o papel por dentro. Fica registrado em `docs/progresso.md`.
- `docs/stack.md` ajustado (falta, baixa e isenção, exclusão de conta, formato dos testes do passo 4), e `docs/progresso.md` com a entrada do passo e o passo 5 como atual.

## Pronto quando

- Tudo verde no local; migrações iguais no local e no remoto; advisors sem alerta novo.
- `docs/progresso.md` aponta o passo 5 como atual.

## Commit

`Fecha o passo 4 — Núcleo financeiro`
