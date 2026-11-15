import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/badge.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/group_models.dart';
import 'group_avatar_view.dart';
import 'groups_providers.dart';

/// Meus grupos (RF25; docs/ui/telas.md, 6.1; groups.png e groups-vazio.png).
/// A lista ocupa o meio, e os dois botões ficam fixos no pé.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final groups = ref.watch(myGroupsProvider);
    Future<void> refresh() => ref.refresh(myGroupsProvider.future);

    return RootTabScaffold(
      title: l10n.navGroups,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: switch (groups) {
              AsyncValue(:final value?) when value.isEmpty => RefreshIndicator(
                onRefresh: refresh,
                child: EmptyState(
                  icon: Symbols.groups,
                  title: l10n.groupsEmptyTitle,
                  body: l10n.groupsEmptyBody,
                ),
              ),
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: refresh,
                child: _GroupList(groups: value),
              ),
              AsyncError(:final error) => ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(myGroupsProvider),
              ),
              _ => const LoadingState(),
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: l10n.groupsCreate,
                  onPressed: () => context.pushNamed(Routes.groupsNew),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.pushNamed(Routes.groupsJoin),
                  child: Text(l10n.groupsJoin, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList({required this.groups});

  final List<GroupSummary> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sorted = [...groups]..sort((a, b) => compareNames(a.name, b.name));
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        ListCard(
          children: [
            for (final group in sorted)
              ListRow(
                leading: GroupAvatarView(
                  id: group.id,
                  name: group.name,
                  photoPath: group.photoPath,
                ),
                title: group.name,
                badge: group.role == GroupRole.admin
                    ? VoleiBadge.neutral(context, l10n.groupRoleAdmin)
                    : null,
                subtitle: _subtitle(l10n, group),
                showChevron: true,
                onTap: () async {
                  await context.pushNamed(
                    Routes.group,
                    pathParameters: {'groupId': group.id},
                  );
                  // Relê ao voltar do detalhe (telas.md, seção 6).
                  if (context.mounted) ref.invalidate(myGroupsProvider);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// "3 integrantes", ou "3 integrantes · 2 solicitações" para o admin com
  /// solicitações pendentes.
  static String _subtitle(AppLocalizations l10n, GroupSummary group) {
    final members = l10n.groupsMemberCount(group.memberCount);
    if (group.role != GroupRole.admin || group.pendingCount == 0) {
      return members;
    }
    return l10n.groupsRowSubtitle(
      members,
      l10n.groupsPendingCount(group.pendingCount),
    );
  }
}
