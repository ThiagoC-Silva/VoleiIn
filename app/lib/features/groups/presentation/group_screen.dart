import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/arrow_rows.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/group_models.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';
import 'group_invite_sheet.dart';
import 'groups_providers.dart';

/// Detalhe do grupo (RF21; docs/ui/telas.md, 6.4; group.png e
/// group-membro.png). Na aba Grupos, com a barra inferior. A fatia 4
/// acrescenta os jogos do grupo e o botão Criar jogo (7.6), entregues pelo
/// roteador em [games].
class GroupScreen extends ConsumerWidget {
  const GroupScreen({required this.groupId, this.games, super.key});

  final String groupId;

  /// A seção "Próximos jogos", da feature de jogos.
  final GroupGamesSlot? games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      appBar: const InnerAppBar(title: ''),
      body: switch (detail) {
        AsyncValue(:final value?) => _GroupBody(group: value, games: games),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

/// Trecho de outra feature dentro do detalhe do grupo, montado pelo roteador
/// (docs/arquitetura-app.md, seção 2): a feature de grupos não importa a de
/// jogos.
/// A sheet de bloqueio da saída ou da remoção do grupo (telas.md, 7.8), que
/// é da feature `games` e chega pelo roteador. [name] só na remoção.
typedef GroupBlockedSheet = Future<void> Function(
  BuildContext context,
  AppException error, {
  String? name,
});

/// Se o erro abre a sheet de bloqueio (RN16), em vez do `SnackBar`.
bool opensBlockedSheet(AppException error) =>
    (error.code == ErrorCode.memberIsReceiver ||
        error.code == ErrorCode.memberIsOnlyGameAdmin) &&
    error.gameIds.isNotEmpty;

class GroupGamesSlot {
  const GroupGamesSlot({
    required this.build,
    required this.refresh,
    this.blocked,
  });

  /// A sheet de bloqueio da saída.
  final GroupBlockedSheet? blocked;

  /// A seção dos jogos do grupo.
  final Widget Function(String groupId) build;

  /// Relê os jogos ao puxar para baixo.
  final Future<void> Function(WidgetRef ref, String groupId) refresh;
}

class _GroupBody extends ConsumerWidget {
  const _GroupBody({required this.group, this.games});

  final GroupDetail group;
  final GroupGamesSlot? games;

  /// Abre uma tela do grupo e relê o grupo ao voltar (telas.md, seção 6).
  Future<void> _open(BuildContext context, WidgetRef ref, String route) async {
    await context.pushNamed(route, pathParameters: {'groupId': group.id});
    if (context.mounted) ref.invalidate(groupDetailProvider(group.id));
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.groupLeaveTitle(group.name),
      body: '${l10n.groupLeaveBody} ${l10n.groupLeaveGamesBody}',
      confirmLabel: l10n.groupLeave,
    );
    if (!confirmed || !context.mounted) return;
    final (gamesLeft, error) = await ref
        .read(groupActionsControllerProvider.notifier)
        .leave(group.id);
    if (!context.mounted) return;
    if (error != null) {
      final blocked = games?.blocked;
      if (blocked != null && opensBlockedSheet(error)) {
        await blocked(context, error);
      } else {
        showErrorSnack(context, error);
      }
      return;
    }
    showSnack(
      context,
      gamesLeft > 0 ? l10n.groupLeftWithGames(gamesLeft) : l10n.groupLeft,
    );
    context.goNamed(Routes.groups);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(groupActionsControllerProvider).isLoading;

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(groupDetailProvider(group.id).future),
        ?games?.refresh(ref, group.id),
      ]),
      child: FormScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        content: [
          Row(
            children: [
              GroupAvatarView(
                id: group.id,
                name: group.name,
                photoPath: group.photoPath,
                size: 72,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(group.name, style: theme.textTheme.headlineMedium),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ArrowRowGroup(
            rows: [
              ArrowRow(
                icon: Symbols.groups,
                title: l10n.groupMembers,
                subtitle: l10n.groupMembersSubtitle(group.memberCount),
                onTap: () => _open(context, ref, Routes.groupMembers),
              ),
              if (group.isAdmin)
                ArrowRow(
                  icon: Symbols.person_add,
                  title: l10n.groupRequests,
                  subtitle: l10n.groupRequestsSubtitle(group.pendingCount),
                  onTap: () => _open(context, ref, Routes.groupRequests),
                ),
              ArrowRow(
                icon: Symbols.link,
                title: l10n.groupInvite,
                subtitle: group.inviteCode == null
                    ? l10n.groupInviteInactive
                    : l10n.groupInviteActive,
                onTap: () => showGroupInviteSheet(context, group.id),
              ),
              if (group.isAdmin)
                ArrowRow(
                  icon: Symbols.edit,
                  title: l10n.groupEdit,
                  subtitle: l10n.groupEditSubtitle,
                  onTap: () => _open(context, ref, Routes.groupEdit),
                ),
            ],
          ),
          if (games case final games?) ...[
            const SizedBox(height: 24),
            games.build(group.id),
          ],
        ],
        // O único membro não sai: ele exclui o grupo em Editar grupo (RN13).
        footer: [
          if (group.memberCount > 1)
            DestructiveOutlinedButton(
              label: l10n.groupLeave,
              onPressed: busy ? null : () => _leave(context, ref),
            ),
        ],
      ),
    );
  }
}
