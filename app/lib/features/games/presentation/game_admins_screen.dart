import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/format/names.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/game_models.dart';
import 'game_controllers.dart';
import 'games_providers.dart';

/// Admins do jogo (RF34, RF35, RN25 a RN27; docs/ui/telas.md, 7.5;
/// gameAdmins.png e gameAdmins-adicionar.png). Só para admins do jogo: os
/// outros veem "não encontrado".
class GameAdminsScreen extends ConsumerWidget {
  const GameAdminsScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(gameDetailProvider(gameId));
    final admins = ref.watch(gameAdminsProvider(gameId));
    Widget body;
    if (game case AsyncValue(value: final detail?)) {
      if (!detail.isAdmin) {
        body = ErrorStateView(
          error: const AppException(ErrorCode.notFound),
          onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
        );
      } else if (admins case AsyncValue(value: final list?)) {
        body = _AdminsBody(game: detail, admins: list);
      } else if (admins case AsyncError(:final error)) {
        body = ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(gameAdminsProvider(gameId)),
        );
      } else {
        body = const LoadingState();
      }
    } else if (game case AsyncError(:final error)) {
      body = ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
      );
    } else {
      body = const LoadingState();
    }
    return Scaffold(
      appBar: InnerAppBar(title: l10n.gameAdmins),
      body: body,
    );
  }
}

class _AdminsBody extends ConsumerWidget {
  const _AdminsBody({required this.game, required this.admins});

  final GameDetail game;
  final List<GameAdmin> admins;

  bool _onList(String userId) => game.participants.any(
    (p) => p.userId == userId && p.status == ParticipantStatus.active,
  );

  GameActionsController _actions(WidgetRef ref) =>
      ref.read(gameActionsControllerProvider.notifier);

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final adminIds = {for (final a in admins) a.userId};
    // Só quem tem passagem active e ainda não é admin, por ordem de entrada
    // (RN27).
    final candidates =
        game.participants
            .where(
              (p) =>
                  p.status == ParticipantStatus.active &&
                  !adminIds.contains(p.userId),
            )
            .toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final chosen = await showVoleiSheet<GameParticipant>(context, (context) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.gameAdminAddSheetTitle,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (candidates.isEmpty)
            Text(l10n.gameAdminsNoCandidates, style: theme.textTheme.bodyMedium)
          else
            ListCard(
              children: [
                for (final person in candidates)
                  ListRow(
                    leading: VoleiAvatar(
                      id: person.userId,
                      name: person.displayName,
                    ),
                    title: person.displayName,
                    onTap: () => Navigator.of(context).pop(person),
                  ),
              ],
            ),
        ],
      );
    });
    if (chosen == null || !context.mounted) return;
    final error = await _actions(ref).addAdmin(game.id, chosen.userId);
    if (!context.mounted) return;
    error == null
        ? showSnack(context, l10n.gameAdminAdded(chosen.displayName))
        : showErrorSnack(context, error);
  }

  Future<void> _tapOther(
    BuildContext context,
    WidgetRef ref,
    GameAdmin admin,
  ) async {
    final l10n = AppLocalizations.of(context);
    final remove = await showVoleiSheet<bool>(context, (context) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(admin.displayName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          SheetOptions(
            options: [
              SheetOption(
                icon: Symbols.person,
                label: l10n.groupMemberViewProfile,
                onTap: () => Navigator.of(context).pop(false),
              ),
              SheetOption(
                icon: Symbols.remove_moderator,
                label: l10n.gameAdminRemove,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      );
    });
    if (remove == null || !context.mounted) return;
    if (!remove) {
      context.pushNamed(
        Routes.gamePerson,
        pathParameters: {'gameId': game.id, 'userId': admin.userId},
      );
      return;
    }
    // Sem confirmação: outro admin pode devolver o papel (telas.md, 7.5).
    final error = await _actions(ref).removeAdmin(game.id, admin.userId);
    if (!context.mounted) return;
    error == null
        ? showSnack(context, l10n.gameAdminRemoved(admin.displayName))
        : showErrorSnack(context, error);
  }

  Future<void> _stepDown(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showVoleiSheet<bool>(
      context,
      (context) => SheetOptions(
        options: [
          SheetOption(
            icon: Symbols.remove_moderator,
            label: l10n.gameAdminStepDown,
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (chosen != true || !context.mounted) return;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.gameAdminStepDownTitle,
      body: l10n.gameAdminStepDownBody,
      confirmLabel: l10n.gameAdminStepDown,
    );
    if (!confirmed || !context.mounted) return;
    final error = await _actions(ref).removeAdmin(game.id, game.viewerId);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSnack(context, l10n.gameAdminSteppedDown);
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(gameActionsControllerProvider).isLoading;
    final sorted = [...admins]
      ..sort((a, b) => compareNames(a.displayName, b.displayName));
    final alone = admins.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            children: [
              ListCard(
                children: [
                  for (final admin in sorted)
                    Builder(
                      builder: (context) {
                        final isYou = admin.userId == game.viewerId;
                        return ListRow(
                          leading: VoleiAvatar(
                            id: admin.userId,
                            name: admin.displayName,
                            isYou: isYou,
                          ),
                          title: isYou
                              ? l10n.groupMemberYou(admin.displayName)
                              : admin.displayName,
                          subtitle: _onList(admin.userId)
                              ? l10n.gameAdminOnList
                              : l10n.gameAdminOffList,
                          // O único admin não toca na própria linha.
                          onTap: isYou
                              ? (alone ? null : () => _stepDown(context, ref))
                              : () => _tapOther(context, ref, admin),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: PrimaryButton(
            label: l10n.gameAdminAdd,
            loading: busy,
            onPressed: () => _add(context, ref),
          ),
        ),
      ],
    );
  }
}
