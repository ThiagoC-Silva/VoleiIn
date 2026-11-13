# Matriz de RLS

> Decisões de 09/11/2026. Base: `modelo-dados.md` (seções 7 e 8), `contratos-api.md` (seção 9), `arquitetura-app.md` (seção 14.2) e o ADR 0015.
> Quem pode ler e escrever o quê no banco e no Storage, inclusive quem **não** pode. Cada linha desta matriz tem um teste pgTAP.
> O documento cresce a cada fatia: a fatia que libera uma tabela escreve aqui as políticas dela antes do código (`plan-docs.md`, seção 8.3).

## 1. Como o acesso funciona

Para o app ler ou escrever uma tabela, **duas camadas** precisam permitir:

| Camada | Decide | Sem ela |
|--------|--------|---------|
| **Privilégio** (`grant`) | Que operação o papel pode fazer e em que colunas | Erro `42501` (*permission denied*) |
| **Política** (RLS) | Em que linhas a operação vale | A leitura volta vazia, e a escrita é recusada |

- **RLS ativado em toda tabela** de `public`, sem exceção. Tabela com RLS e sem política não devolve nenhuma linha.
- **Privilégios padrão revogados** na primeira migração (ADR 0015). **Tabela** nova em `public` nasce sem acesso para `anon` e `authenticated`.
- **Função nova não nasce fechada, e isso é do Postgres.** Toda função recebe `execute` para o papel `public`, que quer dizer "todos os papéis" e inclui `anon` e `authenticated`. O `alter default privileges ... revoke execute on functions from public` **não** tira essa concessão: o Postgres soma o padrão embutido ao que a migração configura (medido em 11/11/2026, no Postgres 17.11 do Supabase local). Um *event trigger* resolveria, mas exige superusuário, que o projeto não tem na produção. Por isso **toda função de `public` leva o `revoke execute ... from public, anon` logo depois do `create`** (`arquitetura-app.md`, 14.3), e o teste B06 fica vermelho se alguma esquecer.
- **Escrita com regra** passa pelas funções `security definer` (`contratos-api.md`), que rodam como dono e não dependem do RLS. O RLS protege a leitura e as escritas diretas da seção 9 do `contratos-api.md`.
- **Realtime** respeita o RLS: o app só recebe eventos de linhas que pode ler. Por isso uma tabela só entra na publicação `supabase_realtime` na fatia que libera a leitura dela.

## 2. Papéis

**Papéis do Postgres**

| Papel | Quem é | Acesso |
|-------|--------|--------|
| `anon` | O app sem login | Nenhum, em nenhuma fatia. O app não lê nada antes do login |
| `authenticated` | O app com login (`auth.uid()` = o usuário) | O que cada fatia conceder |
| `service_role` | Edge Functions do servidor | Ignora o RLS. Nunca vai para o app (`setup.md`, seção 5.1) |
| `postgres` | Migrações, seed e testes | Dono das tabelas |

**Papéis do domínio**, sempre do ponto de vista de quem chama, calculados por funções do esquema `private` (`arquitetura-app.md`, 14.2):

| Papel | Função | Fatia |
|-------|--------|-------|
| Membro do grupo | `private.is_group_member(group_id, user_id)` | 3 |
| Admin do grupo | `private.is_group_admin(group_id, user_id)` | 3 |
| Compartilha contexto (RN107) | `private.shares_context(a, b)` | 3 |
| Admin do jogo | `private.is_game_admin(game_id, user_id)` | 4 |
| Pode ver o jogo | `private.can_view_game(game_id, user_id)` | 4 |
| Participante, recebedor, pagador | Leitura das colunas da própria linha | 4 a 6 |

A definição SQL de cada função entra nesta matriz na fatia indicada.

## 3. Estado base (fatia 1)

A fatia 1 cria o banco inteiro e **não libera nada**. Depois dela:

| Objeto | `anon` | `authenticated` |
|--------|--------|-----------------|
| As 20 tabelas de `public` (`modelo-dados.md`, seção 4) | Nenhum privilégio, nenhuma política | Nenhum privilégio, nenhuma política |
| Funções de `public` | Não há nenhuma | Não há nenhuma |
| Esquema `private` (`emit_notification` e as *triggers*) | Sem `usage` | Sem `usage` |
| Bucket `avatars` | Sem acesso | Sem acesso |
| Bucket `receipts` | Sem acesso | Sem acesso |

- O login técnico (`docs/ui/telas.md`, seção 4) usa só o Supabase Auth e não lê tabela, então não precisa de nenhuma política.
- As *triggers* do esquema `private` são `security definer` e rodam mesmo sem `usage` de quem dispara a escrita.

**Buckets**, criados por migração (`insert into storage.buckets`), para valer igual no local e na produção:

| Bucket | Público | Tamanho máximo | Tipos aceitos | Origem |
|--------|---------|----------------|---------------|--------|
| `avatars` | Não | 2 MB (2.097.152 bytes) | `image/jpeg`, `image/png`, `image/webp` | RN106 |
| `receipts` | Não | 10 MB (10.485.760 bytes) | `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `application/pdf` | RN87 |

O Storage recusa o arquivo fora do tamanho ou do tipo antes de qualquer política. As políticas de `storage.objects` entram nas fatias 2, 3 e 6.

## 4. Quem libera cada tabela

Resumo do `modelo-dados.md` (seção 8), que define o acesso final. A coluna "Fatia" diz quando o acesso é concedido. O detalhe de cada política entra na seção 5 quando a fatia é documentada.

| Tabela ou bucket | Fatia | Leitura (resumo) | Escrita direta (resumo) |
|------------------|-------|------------------|-------------------------|
| `profiles` | 2 (própria linha) e 3 (contexto) | O próprio e quem compartilha contexto (RN107) | Própria linha: `name`, `nickname`, `photo_path` |
| `profile_private` | 2 | Só o dono | Própria linha, com a *trigger* da RN105 |
| `terms_acceptances` | 2 | Só o dono | Inserção da própria linha |
| `groups`, `group_members` | 3 | Membros do grupo | Não |
| `group_join_requests` | 3 | O solicitante e os admins do grupo | Não |
| `games`, `game_admins`, `game_participants`, `game_waitlist` | 4 | `can_view_game` | Não |
| `game_limit_history` | 4 | Admins do jogo | Não |
| `receiver_changes` | 5 | Admins do jogo | Não |
| `charges`, `charge_events` | 5 | O pagador vê os seus; o recebedor e os admins do jogo veem todos do jogo | Não |
| `receipts` | 6 | Pagador e `receiver_id` | Não |
| `notifications` | 7 | Próprio usuário | Só `read_at` |
| `device_tokens`, `notification_preferences` | 7 | Próprio usuário | Próprio usuário |
| `scheduled_notifications_log`, `audit_log` | Nunca | Ninguém pelo app | Não |
| Bucket `avatars` | 2 (perfil) e 3 (grupo) | URL assinada para quem pode ver o perfil ou é membro do grupo | Dono do perfil ou admin do grupo |
| Bucket `receipts` | 6 | Pagador e `receiver_id`, por URL assinada de curta duração | Pagador, para valor `pending` |

## 5. Políticas por fatia

### Fatia 1

Nenhuma política. Os testes provam que nada está aberto (`testes-referencia.md`, seção 9.1):

- toda tabela de `public` tem RLS (B01), e as tabelas são exatamente as 20 do modelo (B02);
- não existe política em `public` (B03) nem em `storage.objects` para os dois buckets (B10);
- `anon` e `authenticated` não têm privilégio em tabela nem `execute` em função de `public` (B04, B06), nem `usage` no esquema `private` (B07);
- tabela criada depois da primeira migração nasce fechada (B05). Função nova, não: o B05 registra o `execute` que o Postgres dá a `public` (seção 1), e quem cobra o fechamento de cada função é o B06.

**Como os testes evoluem.** B03, B04 e B06 comparam o banco com uma **lista esperada**: na fatia 1, as listas são vazias. Cada fatia acrescenta às listas as políticas, os privilégios e as funções que concede, no mesmo PR. Assim, qualquer acesso que ninguém documentou faz o teste falhar.

### Fatia 2

Decisões de 12/11/2026. A pessoa lê e edita **só a própria linha** de `profiles`, `profile_private` e `terms_acceptances`, e envia, lê e apaga **só as próprias fotos** no bucket `avatars`. Ninguém vê o perfil de outra pessoa nesta fatia: a leitura por contexto (RN107) entra na fatia 3, junto com `shares_context`. Nas condições, `uid` é `(select auth.uid())` (seção 6).

**Privilégios de `authenticated`** (lista esperada do B04). `anon` continua sem nenhum.

| Tabela | Privilégio | Colunas |
|--------|------------|---------|
| `profiles` | `select` | Todas |
| `profiles` | `update` | `name`, `nickname`, `photo_path` |
| `profile_private` | `select` | Todas |
| `profile_private` | `update` | `phone`, `phone_visible`, `pix_key_type`, `pix_key` |
| `terms_acceptances` | `select` | Todas |
| `terms_acceptances` | `insert` | `user_id`, `document`, `version` |

- Sem `insert` em `profiles` e `profile_private`: as duas linhas nascem pela *trigger* de `auth.users` (`modelo-dados.md`, 4.1). Sem `delete` em nenhuma das três tabelas.
- O privilégio por coluna impede o app de gravar `id`, `deleted_at`, `display_name`, `updated_at` e `accepted_at`. O `accepted_at` vem sempre do `now()` do servidor (RN02).

**Políticas** (lista esperada do B03)

| Tabela | Política | Operação | `using` | `with check` |
|--------|----------|----------|---------|--------------|
| `profiles` | `profiles_select_own` | `select` | `id = uid` | — |
| `profiles` | `profiles_update_own` | `update` | `id = uid and deleted_at is null` | `id = uid and (photo_path is null or photo_path like 'profiles/' \|\| id::text \|\| '/%')` |
| `profile_private` | `profile_private_select_own` | `select` | `user_id = uid` | — |
| `profile_private` | `profile_private_update_own` | `update` | `user_id = uid` | `user_id = uid` |
| `terms_acceptances` | `terms_acceptances_select_own` | `select` | `user_id = uid` | — |
| `terms_acceptances` | `terms_acceptances_insert_own` | `insert` | — | `user_id = uid and exists (select 1 from public.current_terms_versions() v where v.document = terms_acceptances.document and v.version = terms_acceptances.version)` |

- O `photo_path` só aponta para a pasta da própria pessoa no bucket. Assim ninguém exibe como sua a foto de outra.
- A *trigger* da RN105 roda em todo `update` de `profile_private`, inclusive o do app, e devolve `PIX_KEY_IN_USE` (`contratos-api.md`, seção 2).
- O aceite com versão que não é a vigente, ou com o `user_id` de outra pessoa, é recusado pelo RLS (`42501`).

**Funções** (lista esperada do B06): `public.current_terms_versions()`, com `execute` só para `authenticated` (`contratos-api.md`, seção 9).

**Funções do esquema `private` usadas por constraint.** `private.is_valid_cpf(text)` e `private.is_valid_cnpj(text)` conferem os dígitos da chave Pix na constraint `profile_private_pix_format` (`modelo-dados.md`, 4.1). A constraint roda com os privilégios de quem faz o `update`, inclusive o app, então as duas recebem `execute` para `authenticated` (research R6 de `specs/001-conta-e-perfil`). O `authenticated` continua **sem `usage`** no esquema `private` (B07): a constraint guarda a função pelo OID, e a API não alcança o esquema. A *trigger* da RN105, `private.guard_pix_key_removal()`, é `security definer` e não recebe `execute` de ninguém.

**Storage, bucket `avatars`.** Políticas em `storage.objects`, todas com `bucket_id = 'avatars' and (storage.foldername(name))[1] = 'profiles' and (storage.foldername(name))[2] = uid::text`:

| Política | Operação | Para quê |
|----------|----------|----------|
| `avatars_profile_select_own` | `select` | Gerar a URL assinada da própria foto |
| `avatars_profile_insert_own` | `insert` | Enviar uma foto nova, sempre com nome novo (`profiles/{uid}/{uuid}.{ext}`) |
| `avatars_profile_delete_own` | `delete` | Apagar a foto substituída ou removida (`modelo-dados.md`, seção 7) |

- Sem `update`: o app nunca sobrescreve um arquivo (`upsert: false`). Trocar a foto é enviar a nova, gravar o `photo_path` e apagar a antiga, nesta ordem.
- Tipo e tamanho (RN106) são conferidos pelo próprio bucket, antes das políticas (seção 3).
- A pasta `groups/` continua fechada até a fatia 3. A leitura das fotos de outras pessoas, por contexto, também entra na fatia 3.

**Casos negativos**, cada um com teste (`testes-referencia.md`, seção 10.1): outra pessoa não lê nem edita a linha da Ana nas três tabelas; ninguém grava as colunas fora da lista; ninguém insere em `profiles` ou `profile_private`; ninguém aceita uma versão antiga ou em nome de outro; ninguém envia, lê ou apaga arquivo na pasta de outra pessoa nem em `groups/`; `anon` não lê nada.

## 6. Cuidados nas próximas fatias

- **Desempenho:** nas políticas, use `(select auth.uid())` em vez de `auth.uid()`, para o Postgres calcular uma vez por consulta e não uma vez por linha. As funções auxiliares são `stable` e consultam por colunas indexadas (`modelo-dados.md`, seção 4).
- **Caso negativo sempre:** toda política nova tem ao menos um teste de quem **não** pode (sem contexto, ex-membro, outro pagador), além do teste de quem pode.
- **Simulação do usuário nos testes:** `set local role authenticated` e `set local request.jwt.claims` com o `sub` do usuário (`arquitetura-app.md`, 14.4).
- **Advisors:** ao fim de cada fatia, `get_advisors` do MCP (só leitura) não aponta tabela sem RLS nem política com problema de desempenho.
