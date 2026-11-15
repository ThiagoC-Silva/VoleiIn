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

/// Ordem alfabética de exibição (telas.md, 6.1 e 6.6), sem diferenciar
/// maiúsculas e acentos: "Areia" vem antes de "Vôlei", e "Ângela" junto das
/// outras com "A".
int compareNames(String a, String b) {
  final byFolded = _fold(a).compareTo(_fold(b));
  return byFolded != 0 ? byFolded : a.compareTo(b);
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

String _fold(String text) =>
    text.toLowerCase().split('').map((char) => _accents[char] ?? char).join();
