import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups_repository.dart';
import '../domain/group_models.dart';

// Leituras das telas de grupo (docs/ui/telas.md, seção 6). Sem Realtime: cada
// tela relê ao abrir, ao voltar de outra tela e ao puxar para baixo, e as
// ações chamam `ref.invalidate` depois de gravar (docs/arquitetura-app.md, 5).

final myGroupsProvider = FutureProvider.autoDispose<List<GroupSummary>>(
  (ref) => ref.watch(groupsRepositoryProvider).fetchMyGroups(),
);

final groupDetailProvider = FutureProvider.autoDispose
    .family<GroupDetail, String>(
      (ref, groupId) => ref.watch(groupsRepositoryProvider).fetchGroup(groupId),
    );

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, groupId) =>
          ref.watch(groupsRepositoryProvider).fetchMembers(groupId),
    );

final groupRequestsProvider = FutureProvider.autoDispose
    .family<List<JoinRequest>, String>(
      (ref, groupId) =>
          ref.watch(groupsRepositoryProvider).fetchPendingRequests(groupId),
    );

/// URL assinada da foto do grupo ou de uma pessoa, no bucket `avatars`.
final groupAvatarUrlProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, photoPath) =>
          ref.watch(groupsRepositoryProvider).avatarUrl(photoPath),
    );
