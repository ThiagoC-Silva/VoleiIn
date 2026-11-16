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
| Tem solicitação pendente num grupo que o outro administra (RN107, exceção 2) | `private.has_pending_join_request(requester, admin)` | 3 |
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
| `profiles` | 2 (própria linha) e 3 (contexto) | O próprio, quem compartilha contexto e o admin que decide uma solicitação do dono (RN107) | Própria linha: `name`, `nickname`, `photo_path` |
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

### Fatia 3

Decisões de 15/11/2026. O membro lê o próprio grupo, os integrantes e, se for admin, as solicitações do grupo; quem pediu lê só a própria solicitação. O perfil de outra pessoa passa a ser lido por contexto (RN107) e pelo admin que decide uma solicitação dela (RN107, exceção 2). Toda escrita em grupo passa pelas funções do `contratos-api.md` (seção 3), que são `security definer` e não dependem destas políticas. Nas condições, `uid` é `(select auth.uid())` (seção 6).

**Funções auxiliares**, no esquema `private`, todas `language sql`, `stable`, `security definer` e `set search_path = ''`. Por rodarem como dono, consultam `group_members`, `group_join_requests`, `game_participants` e `game_waitlist` sem passar pelo RLS dessas tabelas, o que também evita a recursão de uma política de `group_members` que consulta `group_members`.

```sql
-- Membro do grupo. Grupo arquivado não tem membros (RN17), então nunca dá verdadeiro.
create function private.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_user_id
  );
$$;

-- Admin do grupo.
create function private.is_group_admin(p_group_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = p_user_id and m.role = 'admin'
  );
$$;

-- Compartilhar contexto (RN107, modelo-dados.md, seção 5): um grupo atual em comum,
-- ou o mesmo jogo, atual ou passado, na lista ou na espera, em qualquer status.
create function private.shares_context(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
      select 1
      from public.group_members ma
      join public.group_members mb on mb.group_id = ma.group_id
      where ma.user_id = p_a and mb.user_id = p_b
    )
    or exists (
      select 1
      from (select game_id from public.game_participants where user_id = p_a
            union
            select game_id from public.game_waitlist where user_id = p_a) ga
      join (select game_id from public.game_participants where user_id = p_b
            union
            select game_id from public.game_waitlist where user_id = p_b) gb
        on gb.game_id = ga.game_id
    );
$$;

-- RN107, exceção 2: p_requester tem solicitação pendente num grupo em que p_admin é admin.
create function private.has_pending_join_request(p_requester uuid, p_admin uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.group_join_requests r
    join public.group_members m
      on m.group_id = r.group_id and m.user_id = p_admin and m.role = 'admin'
    where r.user_id = p_requester and r.status = 'pending'
  );
$$;
```

- **Índices de apoio**, já criados na fatia 1 (`modelo-dados.md`, seção 4): `group_members` pela PK `(group_id, user_id)` e por `(user_id)`; `group_join_requests` pelo único `(group_id, user_id) where status = 'pending'`; `game_participants` por `(user_id, game_id)`; `game_waitlist` por `(user_id)`.
- **Permissões:** as quatro levam `revoke execute ... from public, anon` e `grant execute ... to authenticated`. Como nos validadores da fatia 2, a política roda com os privilégios de quem consulta e guarda a função pelo OID: o `authenticated` precisa de `execute`, mas continua **sem `usage`** no esquema `private` (B07), e a API não alcança as funções.
- `shares_context(a, a)` não é usado: a própria linha já é lida pelas políticas da fatia 2.

**Privilégios de `authenticated`** acrescentados à lista da fatia 2 (lista esperada do B04). `anon` continua sem nenhum.

| Tabela | Privilégio | Colunas |
|--------|------------|---------|
| `groups` | `select` | Todas |
| `group_members` | `select` | Todas |
| `group_join_requests` | `select` | Todas |

- Sem `insert`, `update` e `delete` nas três: as escritas são das funções. O membro lê `invite_code`, porque todo membro vê e compartilha o código (`docs/ui/telas.md`, 6.5).
- `profiles` não ganha privilégio novo: o `select` da fatia 2 já cobre todas as colunas, e as políticas abaixo decidem as linhas.

**Políticas** acrescentadas à lista da fatia 2 (lista esperada do B03)

| Tabela | Política | Operação | `using` |
|--------|----------|----------|---------|
| `groups` | `groups_select_member` | `select` | `private.is_group_member(id, uid)` |
| `group_members` | `group_members_select_member` | `select` | `private.is_group_member(group_id, uid)` |
| `group_join_requests` | `group_join_requests_select_own` | `select` | `user_id = uid` |
| `group_join_requests` | `group_join_requests_select_admin` | `select` | `private.is_group_admin(group_id, uid)` |
| `profiles` | `profiles_select_context` | `select` | `private.shares_context(uid, id)` |
| `profiles` | `profiles_select_join_requester` | `select` | `private.has_pending_join_request(id, uid)` |

- O ex-membro deixa de ler o grupo, os integrantes e as solicitações assim que sai: a linha dele em `group_members` é apagada. O grupo arquivado não é lido por ninguém pelo app.
- O membro que não é admin não lê as solicitações do grupo. Cada pessoa lê as próprias solicitações, em qualquer status, mas não o grupo delas antes de entrar: o nome vem da prévia do convite.
- O perfil lido por contexto inclui o perfil anonimizado (RN104, fatia 6): o histórico continua mostrando a pessoa, sem os dados pessoais.
- A exceção 2 vale só enquanto a solicitação está `pending`. Depois da recusa, o admin deixa de ver a pessoa; depois da aprovação, vale o contexto do grupo.
- `profile_private` continua só do dono, com ou sem contexto. O telefone visível chega a terceiros pela função `get_profile_contact`, na fatia 4 (abaixo).

**Funções do app** acrescentadas à lista do B06, todas com `execute` só para `authenticated`: `create_group(text)`, `update_group(uuid, text, text)`, `regenerate_group_invite(uuid)`, `invalidate_group_invite(uuid)`, `request_group_join(text)`, `decide_join_request(uuid, boolean)`, `set_group_role(uuid, uuid, group_role)`, `leave_group(uuid)`, `remove_group_member(uuid, uuid)` e `archive_group(uuid)`.

**Storage, bucket `avatars`.** Políticas acrescentadas às três da fatia 2, em `storage.objects`, todas com `bucket_id = 'avatars'`. `folder[n]` é `(storage.foldername(name))[n]`. A pasta só é convertida para `uuid` quando tem o formato de um UUID; qualquer outro nome nega a operação, sem erro de conversão.

| Política | Operação | Condição além do bucket | Para quê |
|----------|----------|-------------------------|----------|
| `avatars_profile_select_context` | `select` | `folder[1] = 'profiles' and (private.shares_context(uid, folder[2]::uuid) or private.has_pending_join_request(folder[2]::uuid, uid))` | URL assinada da foto de quem compartilha contexto ou tem solicitação pendente num grupo que quem chama administra |
| `avatars_group_select_member` | `select` | `folder[1] = 'groups' and private.is_group_member(folder[2]::uuid, uid)` | URL assinada da foto do grupo |
| `avatars_group_insert_admin` | `insert` | `folder[1] = 'groups' and private.is_group_admin(folder[2]::uuid, uid)` | Enviar a foto do grupo, sempre com nome novo (`groups/{group_id}/{uuid}.{ext}`) |
| `avatars_group_delete_admin` | `delete` | `folder[1] = 'groups' and private.is_group_admin(folder[2]::uuid, uid)` | Apagar a foto substituída ou removida |

- Sem `update`, como na fatia 2. A prévia do convite (`preview-invite`) gera a URL da foto com a chave de serviço, para quem ainda não é membro (`contratos-api.md`, seção 8).
- `update_group` recusa um `photo_path` fora de `groups/{group_id}/` (`INVALID_INPUT`), como a política de `profiles` faz com a foto de perfil.

**Realtime:** nenhuma tabela de grupo entra na publicação `supabase_realtime` (`stacks.md`, seção 4.1). As telas releem ao abrir e ao puxar para baixo (`docs/ui/telas.md`, seção 6).

**Casos negativos**, cada um com teste (`testes-referencia.md`, seção 11.2): quem não é membro, inclusive o ex-membro, não lê o grupo, os integrantes nem as solicitações; o membro que não é admin não lê as solicitações; ninguém lê o grupo arquivado; ninguém escreve direto nas três tabelas; sem contexto, ninguém lê o perfil nem a foto de outro (RN107); o membro que não é admin não lê o perfil de quem pediu para entrar; depois da recusa, nem o admin; o contexto do grupo acaba quando a pessoa sai ou o grupo é arquivado; o membro não envia nem apaga a foto do grupo; quem não é membro não lê a foto do grupo; `anon` não lê nada.

### Fatia 4

Decisões de 16/11/2026. Quem pode ver o jogo lê o jogo, os admins, a lista de presença e a de espera. O histórico de limite fica só com os admins do jogo. O nome do grupo chega a quem vê o jogo sem ser membro pela função `get_game_groups`, e a chave Pix e o telefone de terceiros, por `get_profile_contact`. Toda escrita em jogo passa pelas funções do `contratos-api.md` (seção 4). Nas condições, `uid` é `(select auth.uid())` (seção 6).

**Funções auxiliares**, no esquema `private`, com as mesmas propriedades das da fatia 3 (`language sql`, `stable`, `security definer`, `set search_path = ''`, `revoke` de `public` e `anon`, `execute` para `authenticated`):

```sql
-- Admin do jogo (RN25).
create function private.is_game_admin(p_game_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.game_admins a
    where a.game_id = p_game_id and a.user_id = p_user_id
  );
$$;

-- Pode ver o jogo (modelo-dados.md, seção 8): membro do grupo do jogo, quem tem ou
-- teve passagem na lista ou na espera, em qualquer status, e admin do jogo.
-- Jogo avulso: só os três últimos. Grupo arquivado não tem membros (RN17).
create function private.can_view_game(p_game_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
      select 1 from public.games g
      join public.group_members m on m.group_id = g.group_id and m.user_id = p_user_id
      where g.id = p_game_id
    )
    or exists (
      select 1 from public.game_participants p
      where p.game_id = p_game_id and p.user_id = p_user_id
    )
    or exists (
      select 1 from public.game_waitlist w
      where w.game_id = p_game_id and w.user_id = p_user_id
    )
    or private.is_game_admin(p_game_id, p_user_id);
$$;
```

- **Índices de apoio**, já criados na fatia 1: `games` pela PK; `group_members` pela PK `(group_id, user_id)`; `game_participants` por `(user_id, game_id)`; `game_waitlist` pela PK `(game_id, user_id)`; `game_admins` pela PK `(game_id, user_id)`.
- O ex-membro continua vendo os jogos em que teve passagem, inclusive o jogo futuro de que saiu pela saída do grupo (RN14), porque a passagem `removed` fica. Assim ele vê o histórico e, na fatia 8, pode voltar pelo convite (RN14, item 1). Os outros jogos do grupo deixam de aparecer.

**Privilégios de `authenticated`** acrescentados às listas das fatias 2 e 3 (lista esperada do B04). `anon` continua sem nenhum.

| Tabela | Privilégio | Colunas |
|--------|------------|---------|
| `games` | `select` | Todas |
| `game_admins` | `select` | Todas |
| `game_participants` | `select` | Todas |
| `game_waitlist` | `select` | Todas |
| `game_limit_history` | `select` | Todas |

- Sem `insert`, `update` e `delete` nas cinco: as escritas são das funções. Quem vê o jogo lê `invite_code`, como o membro do grupo lê o código do grupo. O código só passa a servir para entrar na fatia 8 (seção 6).
- `receiver_changes` continua fechada: abre na fatia 5, com a troca de recebedor.

**Políticas** acrescentadas (lista esperada do B03)

| Tabela | Política | Operação | `using` |
|--------|----------|----------|---------|
| `games` | `games_select_viewer` | `select` | `private.can_view_game(id, uid)` |
| `game_admins` | `game_admins_select_viewer` | `select` | `private.can_view_game(game_id, uid)` |
| `game_participants` | `game_participants_select_viewer` | `select` | `private.can_view_game(game_id, uid)` |
| `game_waitlist` | `game_waitlist_select_viewer` | `select` | `private.can_view_game(game_id, uid)` |
| `game_limit_history` | `game_limit_history_select_admin` | `select` | `private.is_game_admin(game_id, uid)` |

- Quem vê o jogo vê todas as passagens dele, inclusive os cancelamentos e remoções, e todas as linhas da espera. A tela mostra só as passagens que ocupam vaga e a espera atual (`docs/ui/telas.md`, 7.3).
- O perfil dos participantes já é lido pela política `profiles_select_context` da fatia 3: estar no mesmo jogo, na lista ou na espera, é contexto (RN107). Nenhuma política de `profiles` muda.
- As fotos dos participantes seguem a política `avatars_profile_select_context` da fatia 3, pelo mesmo motivo.

**Funções do app** acrescentadas à lista do B06, todas com `execute` só para `authenticated`: `create_game(uuid, text, text, timestamptz, timestamptz, timestamptz, integer, integer)`, `update_game(uuid, text, text, timestamptz, timestamptz, timestamptz, integer)`, `join_game(uuid, text)`, `leave_game(uuid)`, `remove_participant(uuid, uuid)`, `set_slot_limit(uuid, integer)`, `join_waitlist(uuid, text)`, `leave_waitlist(uuid)`, `cancel_game(uuid)`, `add_game_admin(uuid, uuid)`, `remove_game_admin(uuid, uuid)`, `get_profile_contact(uuid)` e `get_game_groups(uuid[])`. `leave_group` e `remove_group_member` mudam de corpo, com a mesma assinatura.

- `get_profile_contact` e `get_game_groups` são `security definer` porque leem `profile_private` e `groups`, que o RLS fecha para terceiros. Cada uma confere a permissão no próprio corpo (`contratos-api.md`, seção 4) e devolve só as colunas que o contrato lista.

**Realtime:** `games`, `game_participants` e `game_waitlist` entram na publicação `supabase_realtime`, por migração (`stacks.md`, 4.1). O Realtime respeita estas políticas: só recebe o evento quem pode ver o jogo (seção 1). `game_admins` e `game_limit_history` ficam fora: as telas que as usam releem ao abrir.

**Casos negativos**, cada um com teste (`testes-referencia.md`, seção 12.4): quem não pode ver o jogo (sem grupo e sem passagem, ou fora do jogo avulso) não lê nenhuma das quatro tabelas; o ex-membro não lê os jogos do grupo em que não teve passagem; quem não é admin do jogo não lê `game_limit_history`, mesmo estando na lista; ninguém escreve direto nas cinco tabelas; quem está só na espera, quem cancelou e quem não está no jogo não recebem a chave Pix do recebedor, nem em jogo cancelado (RN102); o telefone oculto, ou de quem não compartilha contexto, volta nulo (RN101); `get_game_groups` não devolve o grupo de um jogo que quem chama não vê; `anon` não lê nada.

## 6. Cuidados nas próximas fatias

- **Desempenho:** nas políticas, use `(select auth.uid())` em vez de `auth.uid()`, para o Postgres calcular uma vez por consulta e não uma vez por linha. As funções auxiliares são `stable` e consultam por colunas indexadas (`modelo-dados.md`, seção 4).
- **Caso negativo sempre:** toda política nova tem ao menos um teste de quem **não** pode (sem contexto, ex-membro, outro pagador), além do teste de quem pode.
- **Simulação do usuário nos testes:** `set local role authenticated` e `set local request.jwt.claims` com o `sub` do usuário (`arquitetura-app.md`, 14.4).
- **Nome do grupo nos jogos:** resolvido na fatia 4 com a função `get_game_groups` (decisão de 16/11/2026). Liberar `groups` a quem vê o jogo entregaria o `invite_code` do grupo a ex-membros.
- **Código do jogo (fatia 8):** desde a fatia 4, quem pode ver o jogo lê `games.invite_code`, inclusive o membro do grupo que não está na lista e o ex-membro com passagem. Na fatia 8, quando o código passar a servir para entrar, confira se essa leitura continua certa para a RN55 ("qualquer participante pode compartilhar") ou se o código deve sair da tabela lida pelo app.
- **Advisors:** ao fim de cada fatia, `get_advisors` do MCP (só leitura) não aponta tabela sem RLS nem política com problema de desempenho.
