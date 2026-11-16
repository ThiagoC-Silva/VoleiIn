# Contratos internos do app: repositórios da etapa A da fatia 4

A fronteira com o servidor está em `docs/contratos-api.md`, seções 4 e 9, e não muda aqui. Este arquivo descreve **o que cada repositório expõe às telas**, para os testes de widget trocarem por dublês (`docs/arquitetura-app.md`, seção 11). Todo método converte a falha em `AppException` (`arquitetura-app.md`, seção 7).

## Onde fica cada parte

- **Feature `games`** (`app/lib/features/games/`): Meus jogos, Criar jogo, o detalhe, Editar jogo e a seção "Próximos jogos" do detalhe do grupo (`docs/ui/telas.md`, 7.1 a 7.4 e 7.6).
- **Seção do grupo:** a `GroupGamesSection` é da feature `games`, e o roteador a entrega à tela do grupo (research R9; `arquitetura-app.md`, seção 2).
- **Perfil de outra pessoa na aba Jogos:** a mesma `PersonScreen` da feature `auth`, na rota `gamePerson` (research R10).
- **Leituras de outras features:** a feature `games` não usa o `GroupsRepository` nem o `ProfileRepository`. Os grupos da sheet da criação e a chave Pix de quem cria são lidos pelo `GamesRepository`, direto de `groups` e `profile_private`, limitados pelo RLS das fatias 2 e 3.
- **Relógio:** `clockProvider` (`core/clock.dart`), só para mostrar (research R11).
- **Formatos:** a estimativa por pessoa (`estimatedShareCents`, U11) fica em `core/format/money.dart`, e a entrada de dinheiro pela direita (`MoneyInputFormatter` e `parseMoneyInput`, U09), em `core/format/money_input.dart` (`arquitetura-app.md`, seções 4 e 8). Os instantes do formulário (U10) ficam em `features/games/presentation/game_form_values.dart`.
- **Ordem das listas:** é de exibição e fica na `presentation` (`docs/ui/telas.md`, seção 7, "Ordem dos jogos"; RN52 na lista; `joined_at` na espera). O repositório não garante ordem.

## Modelos (`features/games/domain/game_models.dart`)

| Modelo | Campos | Origem |
|--------|--------|--------|
| `GameStatus` | `open`, `confirmed`, `cancelled`, `completed` | Enum `game_status` (`modelo-dados.md`, seção 3) |
| `ParticipantStatus` | `active`, `leftAfterStart`, `cancelled`, `removed` | Enum `participant_status` |
| `GameSummary` | `id`, `groupName` (nulo no avulso), `locationName`, `startsAt`, `endsAt`, `status`, `slotLimit`, `occupiedSlots`, `myStatus` (`active` ou `leftAfterStart`, ou nulo), `myWaitlistPosition` (1, 2... ou nulo) | Card de jogo (7.1). Vagas ocupadas: passagens `active` e `left_after_start` (`modelo-dados.md`, seção 5) |
| `GameParticipant` | `userId`, `displayName`, `photoPath`, `status`, `joinedAt` | Linha da lista de presença (7.3), só as passagens que ocupam vaga |
| `WaitlistEntry` | `userId`, `displayName`, `photoPath`, `joinedAt` | Linha da espera, só com `left_at` nulo |
| `GameDetail` | os dados de `games` que as telas mostram, `groupName`, o nome e a foto do recebedor, `receiverPixKeyType` e `receiverPixKey` (de `get_profile_contact`, nulos sem permissão), `participants`, `waitlist`, `adminIds`, `isGroupMember` e `viewerId` | Detalhe (7.3) e Editar jogo (7.4). Os *getters* `occupiedSlots`, `isAdmin`, `myParticipant` e `myWaitlistPosition` só contam o que veio do servidor |
| `GameGroupOption` | `id`, `name` | Sheet de grupos da criação (7.2) |
| `GameInput` | `locationName`, `mapsUrl`, `cancellationDeadline`, `startsAt`, `endsAt` (UTC), `totalCents`, `slotLimit` | Parâmetros de `create_game` e `update_game` (este sem o limite) |

## `GamesRepository` (`features/games/data/games_repository.dart`)

| Membro | Chama | Erros próprios |
|--------|-------|----------------|
| `fetchMyGames()` → `List<GameSummary>` | `select` em `games`, com as passagens e a espera de cada jogo, e `rpc('get_game_groups')` para os nomes. O RLS limita aos jogos que a pessoa vê (`can_view_game`) | |
| `fetchGroupGames(groupId)` → `List<GameSummary>` | O mesmo, filtrado pelo grupo e pelos status `open` e `confirmed` | |
| `fetchGame(gameId)` → `GameDetail` | `select` do jogo com o recebedor, as passagens que ocupam vaga e a espera com os perfis, os admins, a participação da pessoa no grupo, `get_game_groups` e `get_profile_contact(receiver_id)` | `notFound` quando o RLS não devolve o jogo ou o ID não é um UUID |
| `watchGame(gameId, onChange)` → função que cancela | Canal do Realtime em `games` (filtro `id`), `game_participants` e `game_waitlist` (filtro `game_id`) | |
| `avatarUrl(photoPath)` → `String` | URL assinada no bucket `avatars` | |
| `fetchMyGroupOptions()` → `List<GameGroupOption>` | `select` em `groups`, limitado pelo RLS aos grupos de que a pessoa é membro | |
| `hasPixKey()` → `bool` | `select` de `pix_key` em `profile_private` da própria pessoa | |
| `createGame({groupId, input})` → `String` | `rpc('create_game')`. Devolve o `game_id` | `notFound`, `receiverNeedsPixKey`, `startInPast`, `invalidGameDates`, `invalidInput` |
| `updateGame({gameId, input})` | `rpc('update_game')` | `notFound`, `notGameAdmin`, `gameNotOpen`, `gameStarted`, `invalidGameDates`, `startInPast`, `invalidInput` |
| `setSlotLimit({gameId, slotLimit})` | `rpc('set_slot_limit')` | `notFound`, `notGameAdmin`, `gameNotOpen`, `gameStarted`, `slotLimitBelowParticipants`, `invalidInput` |
| `joinGame(gameId)` | `rpc('join_game')`, sem o código de convite (fatia 8) | `notFound`, `noGameAccess`, `gameNotOpen`, `gameStarted`, `alreadyParticipant`, `gameFull` |
| `joinWaitlist(gameId)` | `rpc('join_waitlist')`, sem o código | `notFound`, `noGameAccess`, `gameNotOpen`, `gameStarted`, `alreadyParticipant`, `gameNotFull`, `alreadyOnWaitlist` |

No Salvar da edição (7.4; S53), a ordem é do controller: `setSlotLimit`, se o limite mudou; depois `updateGame`, se algum outro dado mudou.
