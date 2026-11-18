# Contratos das Funções do Servidor

> Decisões de 06/11/2026. Base: `requisitos.md`, `regras-negocio.md`, `modelo-dados.md`, `stacks.md`, `requisitos-nao-funcionais.md` e `plano-implementacao.md`.
> Este documento define a fronteira entre o app e o backend. As regras continuam nos documentos de origem. Tabelas, enums e o passo a passo de `complete_game` estão no `modelo-dados.md`.

## 1. Convenções

**Chamada**
- Funções SQL são chamadas por `supabase.rpc(nome, parâmetros)`. Edge Functions, por `supabase.functions.invoke(nome, body)`.
- Parâmetros começam com `p_`. Dinheiro é `integer` em centavos. Instantes são `timestamptz`, trafegados em ISO 8601 UTC.
- O retorno de sucesso é `jsonb` em `snake_case`.
- Toda função pública de app é `security definer` com `search_path` vazio, usa `auth.uid()` para saber quem chama, usa `now()` do servidor (RN02) e roda em uma transação. A permissão de execução vai só para `authenticated`.
- Ao tocar em um jogo, a função bloqueia primeiro a linha do jogo (`for update`), para que operações simultâneas fiquem em fila.

**Erros**
- Funções SQL usam `raise exception using errcode = 'P0001', message = '<CODIGO>', detail = '<json opcional>'`. O app lê o código em `message`, e o HTTP é 400.
- Edge Functions respondem `{ "error": { "code": "<CODIGO>", "details": { } } }`, com o HTTP indicado no catálogo.
- O app converte o código no texto da seção 2, sem depender de mensagens do Postgres. Erro desconhecido vira `INTERNAL_ERROR`.
- Violação de índice único em corrida é capturada e convertida no código de negócio correspondente.
- Quando a função valida vários itens, a ordem é: autenticação, existência, papel, estado do recurso e tempo, e por último os dados de entrada. O primeiro que falhar é o devolvido.
- **Sem acesso, sem pista:** quem não pode ver um recurso recebe `NOT_FOUND`. Os códigos de papel, como `NOT_GAME_ADMIN`, só aparecem para quem pode ver o recurso.

**Notificações e auditoria**
- "Notifica" significa chamar `emit_notification` (seção 7), dentro da mesma transação.
- `charge_events` recebe toda transição de status de um valor a pagar, mesmo quando isso não é citado.

## 2. Catálogo de erros

A mensagem é a versão inicial. O texto final fica no catálogo de textos (`plan-docs.md`, seção 4.3).

### Gerais

| Código | HTTP (Edge) | Mensagem |
|--------|-------------|----------|
| `NOT_AUTHENTICATED` | 401 | Entre na sua conta para continuar. |
| `NOT_FOUND` | 404 | Não encontramos o que você procura. |
| `INVALID_INPUT` | 422 | Confira os dados informados. |
| `INTERNAL_ERROR` | 500 | Algo deu errado. Tente de novo. |

### Papéis

| Código | HTTP (Edge) | Mensagem |
|--------|-------------|----------|
| `NOT_A_MEMBER` | — | Você não é membro deste grupo. |
| `NOT_GROUP_ADMIN` | — | Só um admin do grupo pode fazer isso. |
| `NOT_GAME_ADMIN` | — | Só um admin do jogo pode fazer isso. |
| `NOT_CHARGE_PAYER` | 403 | Este valor a pagar não é seu. |
| `NOT_CHARGE_RECEIVER` | — | Só o recebedor deste valor pode fazer isso. |

### Grupos e convites

| Código | Regra | Mensagem |
|--------|-------|----------|
| `INVITE_INVALID` | RN11, RN55 | Este convite não é mais válido. |
| `ALREADY_MEMBER` | RF16 | Você já é membro deste grupo. |
| `JOIN_REQUEST_PENDING` | RN12 | Você já tem uma solicitação pendente neste grupo. |
| `REQUEST_NOT_PENDING` | RF17 | Esta solicitação já foi decidida. |
| `TARGET_NOT_MEMBER` | RF20, RF23 | Esta pessoa não é membro do grupo. |
| `CANNOT_REMOVE_SELF` | RN58 | Para sair, use a opção de saída. |
| `LAST_ADMIN` | RN13 | Promova outro admin antes. O grupo precisa de ao menos um. |
| `MEMBER_IS_RECEIVER` | RN16 | Indique outro recebedor nos jogos em aberto antes. |
| `MEMBER_IS_ONLY_GAME_ADMIN` | RN16 | Indique outro admin nos jogos em aberto antes. |
| `GROUP_HAS_ACTIVE_GAMES` | RN17 | O grupo ainda tem jogos Abertos ou Confirmados. |

### Jogo e lista

| Código | Regra | Mensagem |
|--------|-------|----------|
| `INVALID_GAME_DATES` | RN23 | O prazo não pode passar do início, e o início precisa ser antes do fim. |
| `START_IN_PAST` | RN23, RN33 | O início precisa estar no futuro. |
| `RECEIVER_NEEDS_PIX_KEY` | RN22, RN28 | O recebedor precisa ter uma chave Pix. |
| `NO_GAME_ACCESS` | RN50 | Você precisa ser membro do grupo ou ter o convite do jogo. |
| `GAME_CANCELLED` | RN43 | Este jogo foi cancelado. |
| `GAME_NOT_OPEN` | RN51 | Este jogo já foi cancelado ou concluído. |
| `GAME_FULL` | RN51 | A lista está cheia. Você pode entrar na lista de espera. |
| `GAME_NOT_FULL` | RN51 | Ainda há vagas. Você pode entrar direto na lista. |
| `GAME_STARTED` | RN03, RN33 | O jogo já começou. |
| `GAME_NOT_ENDED` | RN44 | O jogo só pode ser concluído a partir do horário de fim. |
| `LIST_LOCKED` | RN57 | A lista está travada até a conclusão do jogo. |
| `ALREADY_PARTICIPANT` | RN51 | Você já está na lista. |
| `ALREADY_ON_WAITLIST` | RN51 | Você já está na lista de espera. |
| `NOT_ON_WAITLIST` | RN51 | Você não está na lista de espera. |
| `NOT_PARTICIPANT` | RN57, RN58 | Esta pessoa não está na lista. |
| `RECEIVER_LOCKED` | RN29 | Indique outro recebedor antes. |
| `SLOT_LIMIT_BELOW_PARTICIPANTS` | RN33, RN59 | O limite não pode ficar abaixo do número de participantes. |
| `ADMIN_MUST_BE_PARTICIPANT` | RN27 | Só quem está na lista pode ser admin do jogo. |
| `ALREADY_GAME_ADMIN` | RN25 | Esta pessoa já é admin do jogo. |
| `NOT_GAME_ADMIN_TARGET` | RN25 | Esta pessoa não é admin do jogo. |
| `LAST_GAME_ADMIN` | RN25, RN26 | Indique outro admin antes. O jogo precisa de ao menos um. |

### Conclusão, recebedor e multas

| Código | Regra | Mensagem |
|--------|-------|----------|
| `ABSENT_NOT_PARTICIPANT` | RN47 | Só quem está na lista pode ser marcado como faltoso. |
| `RECEIVER_CANNOT_BE_ABSENT` | RF63 | O recebedor não pode ser marcado como faltoso. |
| `RECEIVER_MUST_BE_PARTICIPANT` | RN28 | O novo recebedor precisa estar na lista. |
| `RECEIVER_UNCHANGED` | RF33 | Esta pessoa já é a recebedora do jogo. |
| `RECEIVER_CHANGE_BLOCKED` | RN31 | Há valores Em análise. Decida-os antes de trocar o recebedor. |
| `NOT_A_PENALTY` | RN66 | Só multas podem ser isentadas. |
| `CHARGE_NOT_PENDING` | RN66, RN84, RN86 | Este valor não está mais Pendente. |

### Pagamentos e conta

| Código | Regra | HTTP (Edge) | Mensagem |
|--------|-------|-------------|----------|
| `CHARGE_NOT_REVERTIBLE` | RN85 | — | Só um pagamento marcado manualmente pode ser revertido. |
| `RECEIPT_NOT_UNDER_REVIEW` | RN82, RN83 | — | Este comprovante já foi decidido. |
| `RECEIPT_NOTE_REQUIRED` | RN83 | — | Escreva uma observação para recusar. |
| `RECEIPT_FILE_NOT_FOUND` | RF78 | 422 | Não encontramos o arquivo enviado. Envie de novo. |
| `RECEIPT_TYPE_INVALID` | RN87 | 422 | Envie uma imagem ou um PDF. |
| `RECEIPT_TOO_LARGE` | RN87 | 422 | O arquivo passa de 10 MB. |
| `DUPLICATE_TRANSACTION` | RN89 | 200 (no resultado) | Este comprovante já foi usado em outro pagamento. |
| `ACCOUNT_DELETE_BLOCKED` | RN103 | — | Resolva as pendências antes de excluir a conta. |
| `PIX_KEY_IN_USE` | RN105 | — | Você pode trocar a chave, mas não removê-la enquanto tiver jogos em aberto ou valores a receber. |

## 3. Grupos (fatia 3)

### `create_group(p_name text)`
- **Quem:** usuário autenticado.
- **Erros:** `INVALID_INPUT` (nome fora de 1 a 60 caracteres, contados sem os espaços das pontas).
- **Efeitos:** cria o grupo com o nome sem os espaços das pontas e o código de convite, e torna o criador admin. A foto é enviada depois, com `update_group`, porque o caminho usa o `group_id`.
- **Retorno:** `{ group_id, invite_code }`.
- **Origem:** RF14, RN10, RN11.

### `update_group(p_group_id uuid, p_name text, p_photo_path text)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`, `INVALID_INPUT` (nome como em `create_group`, ou `p_photo_path` fora da pasta `groups/{p_group_id}/`).
- **Efeitos:** grava nome e foto. Passar `p_photo_path` nulo retira a foto. O arquivo antigo é apagado pelo app (`docs/ui/telas.md`, 6.8).
- **Retorno:** `{ group_id }`.
- **Origem:** RF18, RN106.

### `regenerate_group_invite(p_group_id uuid)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`.
- **Efeitos:** gera um novo código e invalida o anterior. As solicitações já criadas não mudam.
- **Retorno:** `{ invite_code }`.
- **Origem:** RF15, RN11.

### `invalidate_group_invite(p_group_id uuid)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`.
- **Efeitos:** deixa o código nulo. Um novo só existe depois de `regenerate_group_invite`.
- **Retorno:** `{ group_id }`.
- **Origem:** RN11.

### `request_group_join(p_invite_code text)`
- **Quem:** usuário autenticado.
- **Erros:** `INVITE_INVALID` (código que não existe, desativado ou de grupo arquivado), `ALREADY_MEMBER`, `JOIN_REQUEST_PENDING`.
- **Efeitos:** cria a solicitação pendente. Notifica cada admin do grupo (`group_join_requested`). O código é comparado exatamente, com maiúsculas e minúsculas; quem tira os espaços é o app. Dois pedidos simultâneos da mesma pessoa: o índice único fica com um, e o outro recebe `JOIN_REQUEST_PENDING`.
- **Retorno:** `{ request_id, group_id }`.
- **Origem:** RF16, RN12, RF89.

### `decide_join_request(p_request_id uuid, p_approve boolean)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`, `REQUEST_NOT_PENDING`. Quem pode ver a solicitação é o solicitante e os admins do grupo (`rls-matriz.md`, fatia 3): um membro que não é admin recebe `NOT_FOUND`, e o próprio solicitante, `NOT_GROUP_ADMIN`.
- **Efeitos:** bloqueia a linha da solicitação (`for update`), grava a decisão com `decided_at` e `decided_by` e, se aprovada, cria o membro com o papel `member`. Notifica o solicitante (`group_join_decided`).
- **Retorno:** `{ request_id, status }`.
- **Origem:** RF17, RF89.

### `set_group_role(p_group_id uuid, p_user_id uuid, p_role group_role)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`, `TARGET_NOT_MEMBER`, `LAST_ADMIN`.
- **Efeitos:** promove ou rebaixa, inclusive a si mesmo. Gravar o papel que a pessoa já tem é aceito e não muda nada. Como as outras funções de grupo, bloqueia a linha do grupo (`for update`): chamadas simultâneas no mesmo grupo ficam em fila, e a segunda é validada com o que a primeira gravou.
- **Retorno:** `{ user_id, role }`.
- **Origem:** RF23, RF24, RN10, RN13.

### `leave_group(p_group_id uuid)` e `remove_group_member(p_group_id uuid, p_user_id uuid)`
- **Quem:** o próprio membro; admin do grupo para remover outra pessoa.
- **Erros:** `NOT_FOUND`, `NOT_A_MEMBER`, `NOT_GROUP_ADMIN`, `TARGET_NOT_MEMBER`, `CANNOT_REMOVE_SELF` (na remoção), `LAST_ADMIN` (na saída), `MEMBER_IS_RECEIVER`, `MEMBER_IS_ONLY_GAME_ADMIN`. Nestes dois últimos, `detail` traz `game_ids`.
- **Efeitos:** retira do grupo, apagando a linha de `group_members`. O último admin recebe `LAST_ADMIN` também quando é o único membro: nesse caso, ele exclui o grupo (RN13). Na fatia 3, a RN16 ainda não é conferida, e `games_left` volta vazio. A partir da fatia 4, também retira das listas de presença e de espera dos jogos do grupo não iniciados, sem multa e com motivo `left_group`, remove o papel de admin dos jogos `open`/`confirmed`, recalcula o status dos jogos e avisa a espera. Na remoção, notifica o removido (`removed_from_group`).
- **RN16, a partir da fatia 4:** os jogos do grupo `open` ou `confirmed`, iniciados ou não, entram na conferência. Ser recebedor vem antes: se a pessoa for recebedora de algum desses jogos, o erro é `MEMBER_IS_RECEIVER`, com `game_ids` desses jogos, mesmo que ela também seja a única admin de algum. Senão, se for a única admin de algum, `MEMBER_IS_ONLY_GAME_ADMIN`, com os `game_ids` deles. Nada muda em nenhum dos dois casos. A conferência vem depois de `LAST_ADMIN` (na saída) e de `TARGET_NOT_MEMBER` (na remoção).
- **Retorno:** `{ games_left: uuid[] }`: os jogos de que a pessoa saiu da lista ou da espera, sem repetir. Os jogos em que ela só perdeu o papel de admin não entram.
- **Origem:** RF20 a RF22, RF102, RN14, RN16, RF104.

### `archive_group(p_group_id uuid)`
- **Quem:** admin do grupo.
- **Erros:** `NOT_FOUND`, `NOT_GROUP_ADMIN`, `GROUP_HAS_ACTIVE_GAMES`.
- **Efeitos:** remove os membros, cancela as solicitações pendentes (`cancelled`, com `decided_at` e `decided_by` nulo, como cancelamento automático), invalida o convite e grava `archived_at` e `archived_by`. Notifica os membros, exceto quem excluiu (`removed_from_group`). Auditoria: `group_archived`. A foto continua em `photo_path` e é apagada pelo `storage-cleanup` (fatia 6).
- **Retorno:** `{ group_id }`.
- **Origem:** RF103, RN17.

### Dados das notificações de grupo

O `p_data` de `emit_notification` em cada evento da fatia 3. O nome do grupo vai junto porque quem foi removido ou recusado deixa de ler o grupo, e a fatia 7 monta o texto a partir destes dados.

| Tipo | Para quem | `p_data` |
|------|-----------|----------|
| `group_join_requested` | Cada admin do grupo | `{ "group_id", "group_name", "request_id" }` |
| `group_join_decided` | O solicitante | `{ "group_id", "group_name", "request_id", "approved": true \| false }` |
| `removed_from_group` | O removido; na exclusão, cada membro exceto quem excluiu | `{ "group_id", "group_name", "reason": "removed" \| "archived" }` |

## 4. Jogo e lista (fatia 4)

### `create_game(p_group_id uuid, p_location_name text, p_maps_url text, p_cancellation_deadline timestamptz, p_starts_at timestamptz, p_ends_at timestamptz, p_total_cents integer, p_slot_limit integer)`
- **Quem:** membro do grupo; em jogo avulso (`p_group_id` nulo), qualquer usuário autenticado.
- **Erros:** `NOT_FOUND`, `RECEIVER_NEEDS_PIX_KEY`, `START_IN_PAST`, `INVALID_GAME_DATES`, `INVALID_INPUT`. Quem não é membro do grupo, inclusive de um grupo arquivado ou que não existe, recebe `NOT_FOUND` (seção 1, "sem acesso, sem pista"), como nas funções de grupo da fatia 3: `NOT_A_MEMBER` não é devolvido aqui.
- **Entrada:** `p_location_name` sem os espaços das pontas, de 1 a 120 caracteres; `p_maps_url` nulo ou começando com `https://`; `p_total_cents >= 1` (RN05); `p_slot_limit >= 1` (RN06). Fora disso, `INVALID_INPUT`.
- **Efeitos:** cria o jogo com `receiver_id` e `created_by` = quem chama, o código de convite (12 caracteres base62, como o do grupo), o admin (`added_by` nulo), a primeira passagem na lista e o histórico de limite (pela *trigger*). O status é `confirmed` se o limite for 1 (RN40). Não notifica ninguém.
- **Retorno:** `{ game_id, status, invite_code }`.
- **Origem:** RF26 a RF32, RN05, RN06, RN20 a RN23, RN40.

### `update_game(p_game_id uuid, p_location_name text, p_maps_url text, p_cancellation_deadline timestamptz, p_starts_at timestamptz, p_ends_at timestamptz, p_total_cents integer)`
- **Quem:** admin do jogo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`, `GAME_STARTED`, `INVALID_GAME_DATES`, `START_IN_PAST`, `INVALID_INPUT`.
- **Entrada:** a mesma de `create_game`.
- **Efeitos:** substitui os dados. O limite de vagas muda por `set_slot_limit`, e o grupo não muda. Cancelamentos já feitos mantêm a classificação (RN35). Notifica os participantes com passagem `active`, exceto quem editou (`game_updated`).
- **Retorno:** `{ game_id }`.
- **Origem:** RF36, RN23, RN33, RN34, RN35, RF91.

### `join_game(p_game_id uuid, p_invite_code text default null)`
- **Quem:** membro do grupo do jogo ou quem tem o código. O parâmetro do código é usado a partir da fatia 8.
- **Erros:** `NOT_FOUND`, `NO_GAME_ACCESS`, `INVITE_INVALID`, `GAME_NOT_OPEN`, `GAME_STARTED`, `ALREADY_PARTICIPANT`, `GAME_FULL`.
- **Acesso:** quem não pode ver o jogo (`can_view_game`, `rls-matriz.md`, fatia 4) recebe `NOT_FOUND`. Quem vê o jogo mas não atende à RN50, porque não é membro do grupo (como o ex-membro com passagem) ou porque o jogo é avulso (como quem saiu da lista de um avulso), recebe `NO_GAME_ACCESS` quando não manda o código. O código passa a valer na fatia 8. A mesma regra vale para `join_waitlist`.
- **Efeitos:** bloqueia o jogo, conta as vagas e cria a passagem com `joined_at = now()`. Fecha a passagem na espera, anula o cancelamento anterior da pessoa (RN56) e recalcula o status. Ao encher, notifica os outros participantes com passagem `active` (`game_confirmed`).
- **Retorno:** `{ participant_id, status }`, em que `status` é o do jogo.
- **Origem:** RF47, RF48, RF51, RF55, RN03, RN50 a RN54, RN56.

### `leave_game(p_game_id uuid)`
- **Quem:** o próprio participante.
- **Erros:** `NOT_FOUND`, `GAME_NOT_OPEN`, `NOT_PARTICIPANT`, `RECEIVER_LOCKED`, `LIST_LOCKED`.
- **Efeitos:**
  - antes do início: `cancelled`, com `late_cancellation` fixado por `now() > prazo`. Libera a vaga, recalcula o status e avisa cada pessoa da espera com `left_at` nulo (`waitlist_slot_opened`);
  - entre o início e o fim: `left_after_start` com falta (`absence_source = left_after_start`). Não libera a vaga.
- **Retorno:** `{ outcome }`, em que `outcome` é `cancelled_on_time`, `cancelled_late` ou `left_after_start`.
- **Origem:** RF50, RN03, RN29, RN35, RN57, RN60, RN61.

### `remove_participant(p_game_id uuid, p_user_id uuid)`
- **Quem:** admin do jogo, nunca sobre si mesmo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`, `GAME_STARTED`, `CANNOT_REMOVE_SELF`, `NOT_PARTICIPANT`, `RECEIVER_LOCKED`.
- **Efeitos:** `removed` com motivo `by_admin`, sem multa. Libera a vaga, recalcula o status e avisa a espera. Notifica o removido (`removed_from_game`).
- **Retorno:** `{ status }`.
- **Origem:** RF54, RF59, RN29, RN58, RF104.

### `set_slot_limit(p_game_id uuid, p_slot_limit integer)`
- **Quem:** admin do jogo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`, `GAME_STARTED`, `SLOT_LIMIT_BELOW_PARTICIPANTS`, `INVALID_INPUT`.
- **Efeitos:** grava o limite (a *trigger* registra o histórico) e recalcula o status. No aumento, avisa a espera (`waitlist_slot_opened`). Notifica os participantes com passagem `active`, exceto quem mudou (`game_updated` e, se a lista encher, `game_confirmed`). Gravar o limite que o jogo já tem é aceito e não notifica.
- **Retorno:** `{ slot_limit, status }`.
- **Origem:** RF52, RF53, RN41, RN42, RN53, RN59.

### `join_waitlist(p_game_id uuid, p_invite_code text default null)` e `leave_waitlist(p_game_id uuid)`
- **Quem:** quem atende à RN50, na entrada; a própria pessoa, na saída.
- **Erros na entrada:** `NOT_FOUND`, `NO_GAME_ACCESS`, `INVITE_INVALID`, `GAME_NOT_OPEN`, `GAME_STARTED`, `GAME_NOT_FULL`, `ALREADY_PARTICIPANT`, `ALREADY_ON_WAITLIST`.
- **Erros na saída:** `NOT_FOUND`, `NOT_ON_WAITLIST`.
- **Efeitos:** entrar cria a linha ou, se ela já existe, limpa `left_at` e grava `joined_at = now()`, para que quem volta à espera fique no fim da ordem (decisão de 16/11/2026). Sair preenche `left_at`. A ordem da espera é só de exibição: a espera não dá prioridade (RN53).
- **Retorno:** `{ game_id }`.
- **Origem:** RF49, RN51, RN54.

### `cancel_game(p_game_id uuid)`
- **Quem:** admin do jogo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`.
- **Efeitos:** `cancelled`, com `cancelled_at = now()` e `cancelled_by`, sem rateio nem multas. Vale também com o jogo em andamento ou depois do fim, até a conclusão (RN43). Notifica, exceto quem cancelou, as passagens `active` e `left_after_start` e a espera com `left_at` nulo (`game_cancelled`).
- **Retorno:** `{ game_id }`.
- **Origem:** RF39, RF66, RN43, RN67, RN114.

### `add_game_admin(p_game_id uuid, p_user_id uuid)` e `remove_game_admin(p_game_id uuid, p_user_id uuid)`
- **Quem:** admin do jogo. Pode remover a si mesmo, desde que haja outro admin.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `ADMIN_MUST_BE_PARTICIPANT` e `ALREADY_GAME_ADMIN` (na adição), `NOT_GAME_ADMIN_TARGET` e `LAST_GAME_ADMIN` (na remoção).
- **Efeitos:** adiciona ou retira o papel, com `added_by` = quem chama. Vale também para jogos concluídos, já que nem o RF34 nem a RN25 limitam o momento e os admins continuam com a isenção de multas. Não notifica.
- **Retorno:** `{ game_id, user_id }`.
- **Origem:** RF34, RF35, RN25 a RN27.

### `regenerate_game_invite(p_game_id uuid)` (fatia 8)
- **Quem:** admin do jogo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`.
- **Efeitos:** gera um novo código e invalida o anterior.
- **Retorno:** `{ invite_code }`.
- **Origem:** RF43, RN55.

### `get_profile_contact(p_user_id uuid)`
- **Quem:** usuário autenticado.
- **Erros:** nenhum. Sem permissão ou com usuário inexistente, os campos voltam nulos.
- **Regras:**
  - quem chama é o próprio dono: devolve o telefone e a chave dele, como estão;
  - `phone`: o dono com `phone_visible = true` e contexto compartilhado com quem chama (RN101, RN107);
  - `pix_key_type` e `pix_key`: esse usuário é o recebedor de um jogo não cancelado em que quem chama tem passagem `active` ou `left_after_start`, ou quem chama tem um valor `pending` ou `under_review` devido a ele (RF45, RF77, RN102).
- **Retorno:** `{ phone, pix_key_type, pix_key }`.
- **Origem:** RF11, RF77, RF101, RN101, RN102, RN107.

### `get_game_groups(p_game_ids uuid[])` (decisão de 16/11/2026)
- **Quem:** usuário autenticado.
- **Erros:** nenhum. IDs que não existem, de jogo avulso ou de jogo que quem chama não pode ver (`can_view_game`) ficam fora do retorno.
- **Efeitos:** nenhum. É `security definer` e lê `groups` só para devolver o nome. Não devolve o código de convite nem os membros.
- **Retorno:** `table (game_id uuid, group_id uuid, group_name text)`, uma linha por jogo de grupo visível. O nome vem também de grupo arquivado: os jogos dele continuam no histórico de quem participou (RN17).
- **Por que existe:** o card e o topo do jogo mostram o nome do grupo, e quem vê o jogo sem ser membro (o ex-membro com o jogo no histórico, e, na fatia 8, quem entrou pelo convite) não lê `groups`, que guarda o `invite_code` do grupo (`rls-matriz.md`, fatia 4).
- **Origem:** RF44, RF45.

### Dados das notificações de jogo

O `p_data` de `emit_notification` em cada evento da fatia 4, no mesmo formato da fatia 3. O local, o início e o nome do grupo vão junto porque quem foi removido ou saiu da espera pode deixar de ver o jogo, e a fatia 7 monta o texto a partir destes dados. `group_name` é nulo em jogo avulso.

| Tipo | Para quem | `p_data` |
|------|-----------|----------|
| `game_confirmed` | Participantes `active`, exceto quem fez a lista encher | `{ "game_id", "group_name", "location_name", "starts_at" }` |
| `game_updated` | Participantes `active`, exceto o admin que mudou | `{ "game_id", "group_name", "location_name", "starts_at" }` |
| `game_cancelled` | Passagens `active` e `left_after_start` e a espera com `left_at` nulo, exceto quem cancelou | `{ "game_id", "group_name", "location_name", "starts_at" }` |
| `waitlist_slot_opened` | Cada pessoa da espera com `left_at` nulo, só antes do início | `{ "game_id", "group_name", "location_name", "starts_at", "reason": "slot_freed" \| "limit_increased" }` |
| `removed_from_game` | Quem foi removido pelo admin | `{ "game_id", "group_name", "location_name", "starts_at" }` |

- Uma operação que libera várias vagas, como a saída do grupo de quem estava em vários jogos, gera um `waitlist_slot_opened` por jogo e por pessoa da espera.

## 5. Conclusão e rateio (fatia 5)

### `preview_complete_game(p_game_id uuid, p_total_cents integer default null, p_absent_user_ids uuid[] default '{}')`
- **Quem:** admin do jogo.
- **Erros:** os mesmos de `complete_game`.
- **Efeitos:** nenhum. Usa o mesmo cálculo de `complete_game` e não grava nada.
- **Retorno:** o mesmo de `complete_game`, com `share_cents`, `total_to_receive_cents`, `receiver_covered_cents`, `uncovered_slots` e `penalties_exempted`.
- **Por que existe:** o RF41 exige mostrar o valor por conta do recebedor antes de confirmar, e o cálculo não pode rodar só no app.
- **Origem:** RF41, RN48, RN74.

### `complete_game(p_game_id uuid, p_total_cents integer default null, p_absent_user_ids uuid[] default '{}')`
- **Quem:** admin do jogo. A conclusão automática usa a mesma lógica interna, sem `auth.uid()` (seção 7).
- **Parâmetros:** `p_total_cents` nulo mantém o valor. `p_absent_user_ids` é a lista **completa** de faltosos: quem saiu após o início e não estiver nela tem a falta desmarcada (RN47).
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_NOT_OPEN`, `GAME_NOT_ENDED`, `ABSENT_NOT_PARTICIPANT`, `RECEIVER_CANNOT_BE_ABSENT`, `INVALID_INPUT`.
- **Efeitos:** passo a passo no `modelo-dados.md` (seção 6). Na RN62, o desempate de `left_at` igual é pelo `id` da linha. O cálculo da parte usa `bigint`. Notifica `game_completed`, `charge_created` e `penalty_waived`. Auditoria: `game_completed`.
- **Retorno:** `{ game_id, share_cents, total_to_receive_cents, receiver_covered_cents, uncovered_slots, penalties_exempted, charges_created }`.
- **Origem:** RF40 a RF42, RF56 a RF63, RF67 a RF71, RN36, RN44 a RN49, RN60 a RN65, RN70 a RN75.

### `change_receiver(p_game_id uuid, p_new_receiver_id uuid)`
- **Quem:** admin do jogo.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `GAME_CANCELLED`, `RECEIVER_UNCHANGED`, `RECEIVER_MUST_BE_PARTICIPANT`, `RECEIVER_NEEDS_PIX_KEY`, `RECEIVER_CHANGE_BLOCKED`.
- **Efeitos antes da conclusão:** troca o recebedor (RN30).
- **Efeitos após a conclusão (RN31), nesta ordem:**
  1. Recusa se houver valor `under_review` no jogo.
  2. O valor `pending` do novo recebedor, de qualquer tipo, passa para `waived` com motivo `receiver_change` (RN94).
  3. Os valores `pending` do jogo passam a ser devidos ao novo recebedor. Os `paid` não mudam.
  4. Se o antigo recebedor **não tiver valor ativo** (diferente de `waived`) no jogo, ganha um `share` `pending` igual a `share_cents`, devido ao novo recebedor. Se tiver, nada é criado: ele já pagou a parte dele.
- **Em ambos os casos:** grava `receiver_changes`, notifica o antigo e o novo recebedor e quem tem valor Pendente (`receiver_changed`) e, se houver novo valor, `charge_created`. Auditoria: `receiver_changed`.
- **Retorno:** `{ game_id, receiver_id, charges_transferred, charge_created }`.
- **Origem:** RF33, RF97, RN28, RN30, RN31, RN32, RN94, RN115.

### `waive_penalty(p_charge_id uuid)`
- **Quem:** admin do jogo do valor.
- **Erros:** `NOT_FOUND`, `NOT_GAME_ADMIN`, `NOT_A_PENALTY`, `CHARGE_NOT_PENDING`.
- **Efeitos:** `waived` com motivo `manual_waiver` e autor. Notifica o participante (`penalty_waived`).
- **Retorno:** `{ charge_id, status }`.
- **Origem:** RF64, RN66, RN93, RF104.

### Dados das notificações de conclusão (decisão de 18/11/2026)

O `p_data` de `emit_notification` nos eventos da fatia 5, no mesmo formato da fatia 4. `amount_cents` e `kind` vão junto para a fatia 7 montar o texto sem ler `charges`.

| Tipo | Para quem | `p_data` |
|------|-----------|----------|
| `game_completed` | Passagens `active` e `left_after_start` e o recebedor, exceto o admin que concluiu. Na automática, sem exceção | `{ "game_id", "group_name", "location_name", "starts_at", "completion_mode" }` |
| `charge_created` | O pagador de cada valor criado, na conclusão ou na troca de recebedor (RN31, item 5) | `{ "game_id", "group_name", "location_name", "starts_at", "charge_id", "kind", "amount_cents" }` |
| `penalty_waived` | Quem teve a multa isentada: na conclusão, cada passagem com `late_cancellation_exempt = true` (sem `charge_id`); em `waive_penalty`, o pagador | `{ "game_id", "group_name", "location_name", "starts_at", "charge_id" \| null, "reason": "automatic" \| "manual_waiver" }` |
| `receiver_changed` | O antigo e o novo recebedor e cada pagador com valor `pending` no jogo depois da troca, exceto o admin que trocou | `{ "game_id", "group_name", "location_name", "starts_at", "old_receiver_id", "new_receiver_id" }` |

- Um mesmo usuário pode receber `game_completed` e `charge_created` na mesma conclusão. A fatia 7 decide se junta os dois no aviso.

## 6. Pagamentos e conta (fatia 6)

### `mark_charge_paid(p_charge_id uuid)`
- **Quem:** o recebedor do valor (`charges.receiver_id`).
- **Erros:** `NOT_FOUND`, `NOT_CHARGE_RECEIVER`, `CHARGE_NOT_PENDING`.
- **Efeitos:** `paid` com `paid_via = manual`. Notifica o pagador (`charge_paid`).
- **Retorno:** `{ charge_id, status }`.
- **Origem:** RF84, RN84, RF97.

### `revert_charge(p_charge_id uuid)`
- **Quem:** o recebedor do valor.
- **Erros:** `NOT_FOUND`, `NOT_CHARGE_RECEIVER`, `CHARGE_NOT_REVERTIBLE`.
- **Efeitos:** volta para `pending`, se `paid_via = manual` e a marcação for do próprio recebedor. `charge_events` guarda quem e quando. Notifica o pagador (`charge_back_to_pending`).
- **Retorno:** `{ charge_id, status }`.
- **Origem:** RF85, RN85, RF97.

### `review_receipt(p_receipt_id uuid, p_approve boolean, p_note text default null)`
- **Quem:** o recebedor do comprovante (`receipts.receiver_id`).
- **Erros:** `NOT_FOUND`, `NOT_CHARGE_RECEIVER`, `RECEIPT_NOT_UNDER_REVIEW`, `RECEIPT_NOTE_REQUIRED`.
- **Efeitos:**
  - aprova: comprovante `approved`, valor `paid` com `paid_via = receipt`. Notifica `charge_paid`;
  - recusa: comprovante `rejected` com motivo `receiver_rejected`, valor volta para `pending`. Notifica `charge_back_to_pending`;
  - em ambos: grava `decided_at`, `decided_by` e `receiver_note`.
- **Retorno:** `{ receipt_id, status, charge_status }`.
- **Origem:** RF83, RN82, RN83, RN90, RN91.

### `delete_account()`
- **Quem:** a própria pessoa.
- **Erros:** `ACCOUNT_DELETE_BLOCKED`, com `detail.reasons` contendo um ou mais de: `pending_charges`, `pending_receivables`, `last_group_admin`, `game_sole_admin`, `game_receiver`.
- **Efeitos, em transação única:**
  1. retira das listas de presença e de espera dos jogos não iniciados, sem multa e com motivo `account_deleted`, recalcula o status e avisa a espera;
  2. retira dos grupos e dos papéis de admin dos jogos `open`/`confirmed`, e cancela as solicitações pendentes;
  3. apaga tokens e preferências;
  4. anonimiza `profiles`, `profile_private` e `auth.users` e bloqueia o acesso. As fotos são apagadas por `storage-cleanup`.
- **Auditoria:** `account_deleted`, sem dados pessoais. O histórico continua associado ao perfil anônimo.
- **Retorno:** `{ deleted: true }`. Em seguida, o app encerra a sessão.
- **Origem:** RF13, RN65, RN103, RN104.

## 7. Funções internas

Sem permissão de execução para o app.

| Função | Chamada por | Faz | Origem |
|--------|-------------|-----|--------|
| `emit_notification(p_type, p_user_id, p_data)` | Funções SQL e Edge Functions | Grava em `notifications` e devolve o `id` da linha. Até a fatia 7, com texto provisório (`title` = o tipo, `body` vazio). A partir dela, com o texto final e o disparo de `send-push` | RN110 |
| `auto_complete_due_games()` | `pg_cron`, a cada 5 minutos | Conclui os jogos com `ends_at + 1h <= now()`, com a mesma lógica de `complete_game` (`completion_mode = automatic`) | RF42, RN45, RN46, RN49 |
| `send_game_reminders()` | `pg_cron`, a cada 5 minutos | Lembretes de prazo e de início (`reminder_cancellation_deadline`, `reminder_game_start`) e aviso de fim (`reminder_complete_game`), sem repetir | RF92 a RF94, RN111, RN112 |
| `send_charge_reminders()` | `pg_cron`, às 9h e às 20h de `America/Fortaleza` | Uma cobrança por usuário com total Pendente (`charge_reminder`) | RF96, RN113 |

## 8. Edge Functions

### `preview-invite` (fatia 3 para grupos, fatia 8 para jogos)

- **Autenticação:** JWT do usuário. Sem login, o app guarda o convite e chama a função depois do login.
- **Corpo:** `{ "code": "<codigo>", "kind": "group" | "game" }`.
- **Erros:** `NOT_AUTHENTICATED`, `INVALID_INPUT`, `INVITE_INVALID` (HTTP 404). Até a fatia 8, `kind: game` responde `INVALID_INPUT`.
- **Efeitos:** nenhum. Roda como Edge Function porque precisa gerar URLs assinadas das fotos.
- **Retorno para grupo:** `{ "kind": "group", "group_id", "name", "photo_url", "is_member", "has_pending_request" }`. `has_pending_request` diz se quem chama já tem solicitação pendente no grupo (decisão de 15/11/2026), para a tela mostrar o pedido no lugar do botão (`docs/ui/telas.md`, 6.3). `photo_url` é nulo quando o grupo não tem foto.
- **Retorno para jogo:** `{ "kind": "game", "game_id", "group_name", "location_name", "maps_url", "cancellation_deadline", "starts_at", "ends_at", "total_cents", "slot_limit", "occupied_slots", "status", "is_participant", "on_waitlist", "participants": [{ "display_name", "photo_url" }] }`.
- **Regras:** a lista traz apelido ou nome e foto dos participantes `active`, por ordem de entrada. Não traz telefone, chave Pix, e-mail nem a lista de espera. As URLs são de curta duração. Um jogo cancelado ou concluído devolve o status, sem a lista.
- **Origem:** RF16, RF48, RN12, RN107 (exceção da prévia).

### `process-receipt` (fatia 6)

- **Autenticação:** JWT do pagador.
- **Corpo:** `{ "charge_id": "<uuid>", "storage_path": "<charge_id>/<uuid>.<ext>" }`. O arquivo é enviado antes ao bucket `receipts`.
- **Erros:** `NOT_AUTHENTICATED`, `INVALID_INPUT` (caminho de outro valor), `NOT_FOUND`, `NOT_CHARGE_PAYER`, `CHARGE_NOT_PENDING` (409), `RECEIPT_FILE_NOT_FOUND`, `RECEIPT_TYPE_INVALID`, `RECEIPT_TOO_LARGE`.
- **Fluxo:** segue o `stacks.md` (seção 6.1).
  1. Com `auto_reads_used >= 3`, grava `under_review` com `auto_read = false`, sem chamar a API.
  2. Caso contrário, chama a API e extrai os campos.
  3. Bloqueia o valor a pagar e confere que ele continua `pending`. Se a API respondeu, mesmo com um comprovante ilegível, incrementa `auto_reads_used` sem passar de 3 e grava `auto_read = true`. Se a API falhou (erro, tempo esgotado ou sem resposta), não incrementa e grava `auto_read = false`.
  4. Se o ID estiver em uso, grava `rejected` com motivo `duplicate_transaction` (a violação do índice único leva ao mesmo resultado).
  5. Se todas as condições da RN88 passarem, grava `approved` e o valor vira `paid`.
  6. Em qualquer outro caso, inclusive falha da API, grava `under_review` e o valor vira `under_review`.
- **Retorno (HTTP 200):** `{ "receipt_id", "result": "approved" | "under_review" | "rejected", "error_code": "DUPLICATE_TRANSACTION" | null, "charge_status", "auto_reads_used" }`. O ID repetido é um resultado registrado, por isso não usa a resposta de erro.
- **Notifica:** `approved` gera `payment_received` para o recebedor e `charge_paid` para o pagador. `under_review` gera `receipt_needs_review`. `rejected` não notifica, porque o pagador vê o motivo na resposta.
- **Tempo limite, tentativas e modelo:** definidos em `docs/comprovantes-ia.md`.
- **Origem:** RF78 a RF83, RN32, RN80, RN81, RN86 a RN92, RF104.

### `send-push` (fatia 7)

- **Autenticação:** chave interna, nunca chamada pelo app.
- **Corpo:** `{ "notification_id": "<uuid>" }`.
- **Erros:** `NOT_AUTHENTICATED`, `NOT_FOUND`.
- **Efeitos:** se a preferência do tipo estiver ativa, envia para todos os aparelhos e grava `push_sent_at`. Apaga tokens invalidados pelo FCM. Falhas de envio ficam no log e não desfazem o histórico.
- **Retorno:** `{ "sent", "failed", "tokens_removed", "skipped_by_preference" }`.
- **Origem:** RF88, RF98, RN110.

### `storage-cleanup` (fatia 6)

- **Autenticação:** chave interna, chamada por `pg_cron` uma vez por dia.
- **Erros:** `NOT_AUTHENTICATED`.
- **Efeitos:** apaga os arquivos pela API do Storage, para que não fiquem órfãos:
  - comprovantes decididos há mais de 30 dias, gravando `file_deleted_at` e deixando `storage_path` nulo (RN91, RN92);
  - arquivos em `receipts` sem registro há mais de 24 horas;
  - fotos em `avatars` que nenhum perfil ou grupo referencia (troca de foto, grupo arquivado, conta anonimizada).
- **Retorno:** `{ "receipts_deleted", "orphans_deleted", "photos_deleted" }`.
- **Origem:** RF87, RN91, RN92, `modelo-dados.md` (seção 7).

## 9. Acesso direto do app

**Escrita direta**, permitida pelo RLS (`modelo-dados.md`, seção 8):

| Tabela ou serviço | O que o app faz | Erros | Origem |
|-------------------|-----------------|-------|--------|
| `profiles` | Edita `name`, `nickname`, `photo_path` da própria linha (fatia 2) | Constraints | RF08, RF09, RF12 |
| `profile_private` | Edita telefone, visibilidade e chave Pix da própria linha (fatia 2). A linha já existe, criada com o perfil | `PIX_KEY_IN_USE` (*trigger*), constraints | RF10 a RF12, RN105 |
| `terms_acceptances` | Insere o próprio aceite, uma linha por documento, só na versão vigente (fatia 2) | Constraints, `42501` com versão que não é a vigente | RF105 |
| `device_tokens` | Registra e apaga os próprios tokens | Constraints | RF07, RF88 |
| `notification_preferences` | Liga e desliga tipos | Constraints | RF98 |
| `notifications` | Grava só `read_at` | — | RF99 |
| Storage | Envia fotos e comprovantes, conforme as políticas e limites da seção 7 do `modelo-dados.md`. A foto do grupo é enviada pelo admin antes de `update_group` (fatia 3) | Erros do Storage | RF09, RF14, RF18, RF78 |
| Supabase Auth | Cadastro, login (e-mail e Google), confirmação, recuperação e troca de e-mail por código de 6 dígitos (`verifyOTP`, ADR 0017), troca de senha e logout | Erros do Auth (`docs/copy.md`) | RF01 a RF07, RF106 a RF108 |

**Leitura:** o app lê as tabelas por `select`, limitado pelo RLS, e assina o Realtime nas tabelas do `stacks.md` (seção 4.1). Consultas de leitura não têm contrato próprio, salvo os totais de RF75 e RF76, que somam `charges` por `status`, o rateio de RF73 e RF74 e a função abaixo.

### `current_terms_versions()` (fatia 2)

- **Retorno:** `table (document legal_document, version text)`, uma linha por documento. Na fatia 2, `terms_of_use` e `privacy_policy`, ambos na versão `1.0`.
- **Permissão:** `authenticated`. Não lê tabela nem depende de quem chama: é `sql`, `immutable` e `security invoker`, com as versões escritas no corpo.
- **Erros:** nenhum.
- **Uso:** o roteador compara com a última versão aceita de cada documento em `terms_acceptances` e manda para `/terms` se faltar alguma (RF105, `arquitetura-app.md`, seção 9). A política de inserção de `terms_acceptances` usa a mesma função (`rls-matriz.md`, fatia 2).
- **Para mudar uma versão:** uma migração nova recria a função com o valor novo. Na próxima abertura, todo mundo que aceitou a versão anterior vê o aceite de novo, em qualquer versão do app.

## 10. Decisões registradas com estes contratos

| Decisão | Registrada em |
|---------|---------------|
| O admin não remove a si mesmo da lista | RN58 |
| Ao trocar de recebedor, quem já tem valor ativo no jogo não ganha outro | RN31 |
| Na edição, o novo início também precisa estar no futuro | RN33 |
| A prévia do convite de jogo mostra os dados e a lista de participantes a quem tem o código e está logado | RN107, `stacks.md` (seção 12) |
| A conclusão e o rateio são função SQL, testada em pgTAP | `stacks.md` (seções 4.1 e 11) |
| A chave Pix do recebedor é visível aos participantes desde a criação do jogo | RN102, RF45, `stacks.md` (seção 12) |
| Uma falha da Claude API manda o comprovante para Em análise e não conta como leitura | RN86, `stacks.md` (seção 6.1) |
| O admin do grupo vê nome e foto de quem tem solicitação pendente no grupo | RN107, `rls-matriz.md` (fatia 3) |
| A prévia do convite de grupo diz se quem chama já tem solicitação pendente | `preview-invite`, `docs/ui/telas.md` (6.3) |
| O nome do grupo dos jogos vem de `get_game_groups`, sem abrir `groups` a quem não é membro | `get_game_groups`, `rls-matriz.md` (fatia 4) |
| Quem volta à lista de espera vai para o fim da ordem | `join_waitlist` |
| Na RN16, ser recebedor é conferido antes de ser o único admin | `leave_group`, `docs/ui/telas.md` (7.8) |
| Quem não pode ver o grupo recebe `NOT_FOUND` ao criar jogo nele, e não `NOT_A_MEMBER` | `create_game`, seção 1 |
| Todo membro vê e compartilha o código do grupo; só os admins o regeneram e desativam | RN11, `docs/ui/telas.md` (6.5) |
| O código de convite continua com 12 caracteres base62, com diferença entre maiúsculas e minúsculas | `modelo-dados.md` (seção 9), `docs/ui/telas.md` (6.3) |
