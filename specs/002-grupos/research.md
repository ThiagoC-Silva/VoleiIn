# Research: Grupos (fatia 3)

Decisões técnicas que os documentos deixam para a implementação. Regra de produto não é decidida aqui.

## R1. Geração do código de convite

- **Decision:** `private.generate_invite_code()` sorteia 12 caracteres base62 com `extensions.gen_random_bytes`, descartando os bytes de 248 a 255 para que cada caractere tenha a mesma chance (248 = 4 × 62). As funções que gravam o código tentam de novo em caso de `unique_violation`, até 5 vezes, e depois devolvem `INTERNAL_ERROR`.
- **Rationale:** `modelo-dados.md` (seção 9, item 3) fixa 12 caracteres base62, cerca de 71 bits. O `random()` do Postgres não é criptográfico, e o resto da divisão sem descarte daria mais peso aos primeiros caracteres. A colisão é tão rara que a nova tentativa só existe por correção.
- **Alternatives considered:** `gen_random_uuid()` cortado (hexadecimal, só 48 bits em 12 caracteres); `random()` (previsível).

## R2. Bloqueio da linha do grupo nas funções que mudam integrantes

- **Decision:** toda função de grupo que muda integrantes, solicitações ou o convite bloqueia primeiro a linha de `groups` (`for update`): `update_group`, `regenerate_group_invite`, `invalidate_group_invite`, `request_group_join`, `decide_join_request`, `set_group_role`, `leave_group`, `remove_group_member` e `archive_group`. A ordem dos bloqueios é sempre grupo e depois solicitação.
- **Rationale:**
  - **C14:** a *trigger* adiável da RN13 confere o grupo no fim de cada transação, mas, sem bloqueio, duas transações que rebaixam pessoas diferentes não esperam uma pela outra. Cada uma confere antes de a outra gravar, e as duas passariam, deixando o grupo sem admin. Com a linha do grupo bloqueada, a segunda espera a primeira terminar e a própria função devolve `LAST_ADMIN`, como o `contratos-api.md` promete. A *trigger* continua como rede de segurança.
  - **Exclusão simultânea a um pedido:** sem bloqueio, `request_group_join` acharia o grupo pelo código, e a solicitação seria gravada depois do arquivamento. Bloqueando a linha, o Postgres relê o grupo depois que o arquivamento termina e não o encontra mais pelo código (`INVITE_INVALID`).
  - **Sem impasse (*deadlock*):** a chave estrangeira de `group_members` e `group_join_requests` também trava a linha do grupo (`for key share`). Se `decide_join_request` travasse a solicitação antes do grupo, ela poderia esperar o `archive_group`, que espera a mesma solicitação. Por isso a ordem fixa: grupo, depois solicitação.
- **Alternatives considered:** nível de isolamento `serializable` (o app teria de repetir as chamadas que falham por serialização); bloqueio consultivo (`pg_advisory_xact_lock`), que faz o mesmo sem a garantia de reler a linha.

## R3. Testes pgTAP com o seed de grupos

- **Decision:** cada teste pgTAP da fatia 3 começa, como `postgres` e dentro da própria transação, apagando as linhas de `group_join_requests` e `group_members` e deixando nulos todos os códigos de convite. Depois insere a base dos cenários (Quinta com `VoleiQuinta1`, Ana admin, Bruno membro). O `rollback` do fim devolve tudo.
- **Rationale:** o seed da fatia 3 (`setup.md`, seção 8) já tem o Vôlei de Quinta com a Carla e o Domingo com o pedido do Diego, e a base dos cenários (`testes-referencia.md`, seção 11) diz que Carla e Diego não estão em nenhum grupo. Sem a limpeza, K05 e K07 veriam as linhas do seed, e o código `VoleiQuinta1` colidiria. A *trigger* adiável da RN13 só dispararia no `commit`, que nunca acontece. O teste roda igual com o seed, sem ele e na cópia da produção do ensaio (`arquitetura-app.md`, 14.4).
- **Alternatives considered:** usar os grupos do seed como base (o teste dependeria do seed, contra a seção 14.4).

## R4. Concorrência pela API, com clientes separados

- **Decision:** C13 a C15 usam o `@supabase/supabase-js`, já no `deno.json`, com um cliente por pessoa logada. As duas chamadas saem juntas (`Promise.all`) e chegam ao PostgREST, que atende cada uma numa conexão própria do *pool*. Cada repetição devolve o seed ao estado inicial pelas próprias funções (recusa do pedido, saída, rebaixamento).
- **Rationale:** o requisito é ter conexões separadas ao banco local (`arquitetura-app.md`, 14.4). Pela API, cada chamada é uma transação em outra conexão, o mesmo caminho do app, sem pacote novo (`trabalho-com-agente.md`, seção 7).
- **Efeito colateral:** C13 e C15 deixam solicitações recusadas do Diego no Vôlei de Quinta do banco local (uma por repetição). Elas não mudam nenhum outro cenário: só a pendente conta para a RN12, para a prévia (Q01) e para a RN107. O `supabase db reset` as apaga.
- **Alternatives considered:** um driver de Postgres no Deno (pacote fora da lista, exigiria pergunta); a chave de serviço para limpar (mais um segredo no job do CI).

## R5. `preview-invite`: JWT conferido dentro da função

- **Decision:** a função roda com `verify_jwt = false` no `config.toml` e confere o JWT ela mesma, com `auth.getUser(token)`, respondendo `401 NOT_AUTHENTICATED` no formato do `contratos-api.md` (seção 1). A consulta ao grupo e a URL assinada usam um cliente com a chave de serviço, que o Edge Runtime fornece em `SUPABASE_SERVICE_ROLE_KEY`. A URL vale 10 minutos.
- **Rationale:** com a conferência no *gateway*, a falta de login volta como `401` com o corpo do Supabase, e não com `{ "error": { "code": "NOT_AUTHENTICATED" } }`, que o Q05 e o app esperam. As chaves novas do Supabase (`sb_publishable_...`) também não são JWT, e a documentação do Supabase recomenda conferir dentro da função. Quem chama ainda não é membro, então só a chave de serviço lê o grupo e assina a foto (`rls-matriz.md`, fatia 3).
- **Alternatives considered:** uma função SQL `security definer` para os dados e outra chamada para a foto (o app faria duas chamadas, e a assinatura da URL continuaria fora do SQL).

## R6. Testes Deno da `preview-invite` no job do banco

- **Decision:** o `index_test.ts` da `preview-invite` fala com a função servida pelo Supabase local, por isso passa a rodar no job `database` do CI, junto da pasta `_tests/`. O job `functions` continua com `deno fmt --check` e `deno lint`, e roda só os testes que não precisam do Supabase (nenhum nesta fatia).
- **Rationale:** `testes-referencia.md` (11.4) pede o teste contra o Supabase local com o seed. O job `functions` não sobe o Supabase.
- **Alternatives considered:** subir o Supabase também no job `functions` (dois `supabase start` por PR).
