# Contratos internos do app: repositórios da fatia 3

A fronteira com o servidor está em `docs/contratos-api.md`, seções 3, 8 e 9, e não muda aqui. Este arquivo descreve **o que cada repositório expõe às telas**, para os testes de widget trocarem por dublês (`docs/arquitetura-app.md`, seção 11). Todo método converte a falha em `AppException` (`arquitetura-app.md`, seção 7).

## Onde fica cada parte

- **Feature `groups`** (`app/lib/features/groups/`): os grupos, o convite, as solicitações e os integrantes (RF14 a RF25, RF102, RF103), como manda a seção 2 do `arquitetura-app.md`.
- **Perfil de outra pessoa** (`/people/:userId`): fica na feature `auth`, que já tem o RF101 (telefone de outra pessoa, fatia 4) e o modelo `Profile`. O `ProfileRepository` ganha `fetchProfile`, e a tela usa o `avatarUrlProvider` que já existe. A rota fica no ramo da aba Grupos, a única origem na fatia 3 (`docs/ui/telas.md`, 6.9). A fatia 4 decide como abrir a mesma tela pela aba Jogos.
- **Compartilhar** (`app/lib/core/share.dart`): o `Sharer`, que embrulha o `share_plus`, para o teste conferir o texto (S28) sem abrir o seletor do Android.
- **Ordem das listas:** a ordem é de exibição e fica na `presentation`: alfabética em Meus grupos e em Integrantes (admins primeiro), sem diferenciar maiúsculas e acentos, e por `created_at` em Solicitações. O repositório não garante ordem (as solicitações já vêm por `created_at`, mas a tela ordena de novo, para o S32 conferir com um dublê).
- **Partes comuns movidas para `core/`** (`arquitetura-app.md`, seção 2: uma feature não lê o `data` nem o `presentation` de outra): o `PhotoPicker` e o `PhotoChange`, que estavam em `features/auth/`, foram para `core/photo_picker.dart`; o `SubmitController`, para `core/submit_controller.dart`; a sheet da foto, para `shared/widgets/sheet_option.dart`.
- **Sessão:** as telas de grupo leem o usuário logado pelo `sessionUserIdProvider` da feature `auth`, a exceção registrada no `arquitetura-app.md`, seção 2.

## Modelos (`features/groups/domain/`)

| Modelo | Campos | Origem |
|--------|--------|--------|
| `GroupRole` | `admin`, `member` | Enum `group_role` (`modelo-dados.md`, seção 3) |
| `GroupSummary` | `id`, `name`, `photoPath`, `memberCount`, `role`, `pendingCount` | Linha de Meus grupos (6.1). `pendingCount` só conta para admin |
| `GroupDetail` | `id`, `name`, `photoPath`, `inviteCode`, `memberCount`, `myRole`, `pendingCount` | Detalhe (6.4) e sheet do convite (6.5). `inviteCode` nulo é o convite desativado |
| `GroupMember` | `userId`, `role`, `joinedAt`, `displayName`, `photoPath` | Linha de Integrantes (6.6) |
| `JoinRequest` | `id`, `userId`, `createdAt`, `displayName`, `photoPath` | Linha de Solicitações (6.7) |
| `InvitePreview` | `groupId`, `name`, `photoUrl`, `isMember`, `hasPendingRequest` | Retorno da `preview-invite` para grupo (`contratos-api.md`, seção 8) |

`invite_code.dart` traz `normalizeInviteCode(typed)`: tira todos os espaços e devolve o código se sobrarem 12 letras ou números, ou nulo. A caixa é mantida (U08). É a mesma regra da constraint do banco, só para o aviso no campo.

## `GroupsRepository` (`features/groups/data/groups_repository.dart`)

| Membro | Chama | Erros próprios |
|--------|-------|----------------|
| `fetchMyGroups()` → `List<GroupSummary>` | `select` em `groups`, com a contagem de `group_members` e das solicitações `pending`, e o papel da pessoa em `group_members`. O RLS limita aos grupos de que ela é membro | |
| `fetchGroup(groupId)` → `GroupDetail` | `select` do grupo, com as contagens, e do papel da pessoa | `notFound` quando o RLS não devolve a linha ou o ID não é um UUID |
| `fetchMembers(groupId)` → `List<GroupMember>` | `select` em `group_members` com `profiles(display_name, photo_path)` | `notFound` com a lista vazia |
| `fetchPendingRequests(groupId)` → `List<JoinRequest>` | `select` em `group_join_requests` `pending`, por `created_at`, com o perfil de quem pediu | |
| `avatarUrl(photoPath)` → `String` | URL assinada no bucket `avatars`, para a foto do grupo e a das pessoas | |
| `previewInvite(code)` → `InvitePreview` | `functions.invoke('preview-invite', {code, kind: 'group'})` | `inviteInvalid` |
| `createGroup(name)` → `String` | `rpc('create_group')`. Devolve o `group_id` | `invalidInput` |
| `uploadGroupPhoto({groupId, bytes, extension})` → caminho | Envio para `groups/{groupId}/{uuid}.{ext}`, sem sobrescrever | `photoTooLarge`, `photoInvalidType` |
| `updateGroup({groupId, name, photoPath})` | `rpc('update_group')` | `notFound`, `notGroupAdmin`, `invalidInput` |
| `deleteGroupPhoto(photoPath)` | Remoção no bucket | |
| `regenerateInvite(groupId)` → `String` | `rpc('regenerate_group_invite')`. Devolve o código novo | `notFound`, `notGroupAdmin` |
| `invalidateInvite(groupId)` | `rpc('invalidate_group_invite')` | `notFound`, `notGroupAdmin` |
| `requestJoin(code)` | `rpc('request_group_join')` | `inviteInvalid`, `alreadyMember`, `joinRequestPending` |
| `decideRequest({requestId, approve})` | `rpc('decide_join_request')` | `notFound`, `notGroupAdmin`, `requestNotPending` |
| `setRole({groupId, userId, role})` | `rpc('set_group_role')` | `notFound`, `notGroupAdmin`, `targetNotMember`, `lastAdmin` |
| `leaveGroup(groupId)` | `rpc('leave_group')` | `notFound`, `notAMember`, `lastAdmin` |
| `removeMember({groupId, userId})` | `rpc('remove_group_member')` | `notFound`, `notGroupAdmin`, `targetNotMember`, `cannotRemoveSelf` |
| `archiveGroup(groupId)` | `rpc('archive_group')` | `notFound`, `notGroupAdmin`, `groupHasActiveGames` |

A ordem das chamadas na criação com foto (`telas.md`, 6.2; S21) e no Salvar da edição (6.8; S33) é dos controllers: `createGroup`, `uploadGroupPhoto`, `updateGroup`; e `uploadGroupPhoto`, `updateGroup`, `deleteGroupPhoto`. A foto é escolhida pelo `PhotoPicker` (`core/photo_picker.dart`).

## `ProfileRepository` (`features/auth/data/profile_repository.dart`), acréscimo

| Membro | Chama | Erros próprios |
|--------|-------|----------------|
| `fetchProfile(userId)` → `Profile` | `select` em `profiles`, decidido pelo RLS (contexto ou solicitação pendente, `rls-matriz.md`, fatia 3) | `notFound` sem linha ou com ID que não é UUID, sem dizer qual dos dois |

## `Sharer` (`core/share.dart`)

| Membro | Faz |
|--------|-----|
| `shareText(text)` | Abre o compartilhamento do Android com o texto (`share_plus`) |
