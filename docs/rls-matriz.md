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
| Conta não excluída | `private.is_active_account(user_id)` | 6 |

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

### Fatia 5

Decisões de 18/11/2026. O pagador lê os próprios valores; o recebedor atual do jogo e os admins do jogo leem todos os valores do jogo (RN76); e quem é o `receiver_id` de um valor o lê, mesmo depois de deixar de ser o recebedor do jogo (RN31, item 2: o valor Pago continua com ele). Os eventos de um valor seguem a leitura do valor. As trocas de recebedor ficam com os admins do jogo. `audit_log` continua fechada. Toda escrita passa pelas funções do `contratos-api.md` (seção 5). Nas condições, `uid` é `(select auth.uid())` (seção 6).

**Funções auxiliares**, no esquema `private`, com as mesmas propriedades das fatias anteriores:

```sql
-- Recebedor atual do jogo (RN28).
create function private.is_game_receiver(p_game_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.games g
    where g.id = p_game_id and g.receiver_id = p_user_id
  );
$$;

-- Pode ver o valor a pagar: o pagador, o recebedor do valor (RN32), o recebedor
-- atual do jogo e os admins do jogo (RN76).
create function private.can_view_charge(p_charge_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.charges c
    where c.id = p_charge_id
      and (c.payer_id = p_user_id
        or c.receiver_id = p_user_id
        or private.is_game_receiver(c.game_id, p_user_id)
        or private.is_game_admin(c.game_id, p_user_id))
  );
$$;
```

- **Índices de apoio**, já criados na fatia 1: `charges` pela PK, por `(payer_id, status)`, `(receiver_id, status)` e `(game_id)`; `charge_events` por `(charge_id, created_at)`; `games` pela PK.
- O antigo recebedor que não é admin deixa de ver o rateio completo depois da troca. Continua vendo os valores devidos a ele (os Pagos) e o próprio valor novo, como pagador.

**Privilégios de `authenticated`** acrescentados às listas das fatias anteriores (lista esperada do B04). `anon` continua sem nenhum.

| Tabela | Privilégio | Colunas |
|--------|------------|---------|
| `charges` | `select` | Todas |
| `charge_events` | `select` | Todas |
| `receiver_changes` | `select` | Todas |

- Sem `insert`, `update` e `delete` nas três: as escritas são das funções. `audit_log` continua sem privilégio.

**Políticas** acrescentadas (lista esperada do B03)

| Tabela | Política | Operação | `using` |
|--------|----------|----------|---------|
| `charges` | `charges_select_party` | `select` | `payer_id = uid or receiver_id = uid or private.is_game_receiver(game_id, uid) or private.is_game_admin(game_id, uid)` |
| `charge_events` | `charge_events_select_party` | `select` | `private.can_view_charge(charge_id, uid)` |
| `receiver_changes` | `receiver_changes_select_admin` | `select` | `private.is_game_admin(game_id, uid)` |

- A política de `charges` escreve as condições do pagador e do recebedor do valor direto nas colunas, sem a função, para usar os índices `(payer_id, status)` e `(receiver_id, status)` nos totais da aba Cobranças.
- Os nomes nas telas de rateio e de cobranças vêm de `profiles` pela política `profiles_select_context` da fatia 3: todo pagador teve passagem no jogo, e isso é contexto (RN107). Nenhuma política de `profiles` muda.

**Funções do app** acrescentadas à lista do B06, todas com `execute` só para `authenticated`: `preview_complete_game(uuid, integer, uuid[])`, `complete_game(uuid, integer, uuid[])`, `change_receiver(uuid, uuid)` e `waive_penalty(uuid)`. `auto_complete_due_games()` é interna (`contratos-api.md`, seção 7): sem `execute` para `anon` nem `authenticated`, chamada só pelo `pg_cron`.

**Realtime:** nada muda. `charges` fica fora da publicação: as telas da fatia 5 releem ao abrir (`docs/ui/telas.md`, seção 8), e o detalhe do jogo já recebe a mudança de status de `games`.

**Casos negativos**, cada um com teste (`testes-referencia.md`, seção 13.4): outro pagador do mesmo jogo não lê o valor de ninguém além do próprio, nem os eventos dele; quem está na lista sem valor e sem ser admin ou recebedor não lê nenhum valor do jogo; quem não está no jogo não lê nada; o antigo recebedor, sem ser admin, não lê os valores Pendentes que passaram ao novo; quem não é admin do jogo não lê `receiver_changes`, nem sendo o recebedor; ninguém escreve direto nas três tabelas; `audit_log` continua fechada; `anon` não lê nada; o app não executa `auto_complete_due_games`.

### Fatia 6

Decisões de 24/11/2026. O comprovante, com o arquivo e os dados lidos, é só do **pagador** e do **recebedor gravado no comprovante** (RF87). Os admins do jogo e o recebedor atual do jogo, quando não é o do comprovante, não leem. Toda escrita em `charges`, `charge_events` e `receipts` continua nas funções. A conta excluída não escreve mais nada. Nas condições, `uid` é `(select auth.uid())` (seção 6).

**Funções auxiliares**, no esquema `private`, com as mesmas propriedades e permissões das fatias anteriores:

```sql
-- Conta não excluída (RN104). Barra o token que sobra depois da exclusão.
create function private.is_active_account(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p where p.id = p_user_id and p.deleted_at is null
  );
$$;

-- Pode enviar um arquivo de comprovante: o pagador de um valor Pendente (RN86).
create function private.can_upload_receipt(p_charge_id uuid, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.charges c
    where c.id = p_charge_id and c.payer_id = p_user_id and c.status = 'pending'
  ) and private.is_active_account(p_user_id);
$$;

-- Pode abrir o arquivo: quem pagou ou quem recebe, pelo registro do comprovante.
create function private.can_read_receipt_file(p_path text, p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.receipts r
    where r.storage_path = p_path and (r.payer_id = p_user_id or r.receiver_id = p_user_id)
  );
$$;
```

- **Índices de apoio:** `receipts` por `(charge_id, created_at)` e `(receiver_id, status)`, da fatia 1. A leitura do arquivo consulta `storage_path`: a etapa B cria um índice único parcial `(storage_path) where storage_path is not null`, que também impede o mesmo arquivo em dois comprovantes.
- `private.require_uid()` passa a chamar `is_active_account` (`NOT_AUTHENTICATED`).

**Privilégios de `authenticated`** acrescentados (lista esperada do B04). `anon` continua sem nenhum.

| Tabela | Privilégio | Colunas | Etapa |
|--------|------------|---------|-------|
| `receipts` | `select` | Todas | B |

**Políticas** acrescentadas ou alteradas (lista esperada do B03)

| Tabela | Política | Operação | Condição | Etapa |
|--------|----------|----------|----------|-------|
| `receipts` | `receipts_select_party` | `select` | `payer_id = uid or receiver_id = uid` | B |
| `profile_private` | `profile_private_update_own` | `update` | `using` e `with check`: `user_id = uid and private.is_active_account(uid)` | C |
| `terms_acceptances` | `terms_acceptances_insert_own` | `insert` | A condição da fatia 2 **e** `private.is_active_account(uid)` | C |

- `profiles_update_own` já exige `deleted_at is null` desde a fatia 2.
- O antigo recebedor continua lendo os comprovantes enviados a ele, e o novo não os vê: `receipts.receiver_id` é o do envio (RN32).

**Storage, bucket `receipts`.** Políticas em `storage.objects`, todas com `bucket_id = 'receipts'`. A pasta só é convertida para `uuid` quando tem o formato de um UUID.

| Política | Operação | Condição além do bucket | Etapa |
|----------|----------|-------------------------|-------|
| `receipts_insert_payer` | `insert` | `private.can_upload_receipt(folder[1]::uuid, uid)`, com o nome no formato `{charge_id}/{uuid}.{ext}`, sem subpasta | B |
| `receipts_select_party` | `select` | `private.can_read_receipt_file(name, uid)` | B |
| `avatars_profile_insert_own` (alterada) | `insert` | A condição da fatia 2 **e** `private.is_active_account(uid)` | C |

- Sem `update` e `delete`: o app não troca nem apaga comprovante. O arquivo só sai por `storage-cleanup`.
- O arquivo enviado e ainda sem registro não é lido por ninguém pelo app. `process-receipt` o lê com a chave de serviço.

**Funções** acrescentadas à lista do B06, com `execute` só para `authenticated`: `mark_charge_paid(uuid)` e `revert_charge(uuid)` (etapa A), `review_receipt(uuid, boolean, text)` (B) e `delete_account()` (C). **Só para `service_role`** (ADR 0019), conferidas no mesmo teste: `record_receipt(uuid, uuid, text, text, integer, jsonb)` (B), `list_storage_cleanup()` e `mark_receipts_file_deleted(uuid[])` (C).

**Realtime:** nada muda. `charges` e `receipts` ficam fora da publicação. As telas releem (`docs/ui/telas.md`, seção 9).

**Casos negativos**, cada um com teste (`testes-referencia.md`, seção 14.5): o admin do jogo, o recebedor atual que não é o do comprovante, outro pagador e quem está fora do jogo não leem o comprovante nem o arquivo; ninguém envia arquivo para valor de outro, para valor que não está Pendente ou fora do formato; ninguém sobrescreve nem apaga arquivo; ninguém escreve direto em `receipts`; o app não executa as funções de `service_role`; a conta excluída, com o token ainda válido, não chama função nem escreve; `anon` não lê nada.

## 6. Cuidados nas próximas fatias

- **Desempenho:** nas políticas, use `(select auth.uid())` em vez de `auth.uid()`, para o Postgres calcular uma vez por consulta e não uma vez por linha. As funções auxiliares são `stable` e consultam por colunas indexadas (`modelo-dados.md`, seção 4).
- **Caso negativo sempre:** toda política nova tem ao menos um teste de quem **não** pode (sem contexto, ex-membro, outro pagador), além do teste de quem pode.
- **Simulação do usuário nos testes:** `set local role authenticated` e `set local request.jwt.claims` com o `sub` do usuário (`arquitetura-app.md`, 14.4).
- **Nome do grupo nos jogos:** resolvido na fatia 4 com a função `get_game_groups` (decisão de 16/11/2026). Liberar `groups` a quem vê o jogo entregaria o `invite_code` do grupo a ex-membros.
- **Código do jogo (fatia 8):** desde a fatia 4, quem pode ver o jogo lê `games.invite_code`, inclusive o membro do grupo que não está na lista e o ex-membro com passagem. Na fatia 8, quando o código passar a servir para entrar, confira se essa leitura continua certa para a RN55 ("qualquer participante pode compartilhar") ou se o código deve sair da tabela lida pelo app.
- **Advisors:** ao fim de cada fatia, `get_advisors` do MCP (só leitura) não aponta tabela sem RLS nem política com problema de desempenho.
