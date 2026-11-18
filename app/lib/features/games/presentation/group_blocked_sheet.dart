import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/state_views.dart';
import 'game_card.dart';
import 'games_providers.dart';

/// Sheet de bloqueio da saída ou da remoção do grupo (RF102, RN16;
/// docs/ui/telas.md, 7.8; group-sairBloqueado.png), com os cards dos jogos de
/// `detail.game_ids`. Sem [name], é a própria pessoa saindo; com ele, a
/// remoção dessa pessoa. A feature `groups` a recebe do roteador
/// (docs/arquitetura-app.md, seção 2).
Future<void> showGroupBlockedSheet(
  BuildContext context,
  AppException error, {
  String? name,
}) {
  final l10n = AppLocalizations.of(context);
  final receiver = error.code == ErrorCode.memberIsReceiver;
  final title = name == null
      ? l10n.groupLeaveBlockedTitle
      : l10n.groupRemoveBlockedTitle(name);
  final body = switch ((receiver, name)) {
    (true, null) => l10n.groupBlockedReceiverBody,
    (false, null) => l10n.groupBlockedOnlyAdminBody,
    (true, final String who) => l10n.groupRemoveBlockedReceiverBody(who),
    (false, final String who) => l10n.groupRemoveBlockedOnlyAdminBody(who),
  };
  return showVoleiSheet<void>(context, (sheetContext) {
    final theme = Theme.of(sheetContext);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        _BlockedGames(
          gameIds: error.gameIds,
          onOpen: (gameId) {
            Navigator.of(sheetContext).pop();
            context.goNamed(Routes.game, pathParameters: {'gameId': gameId});
          },
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.commonBack),
        ),
      ],
    );
  });
}

class _BlockedGames extends ConsumerWidget {
  const _BlockedGames({required this.gameIds, required this.onOpen});

  final List<String> gameIds;
  final void Function(String gameId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gameIds.isEmpty) return const SizedBox.shrink();
    final games = ref.watch(gameSummariesProvider(gameIds.join(',')));
    return switch (games) {
      AsyncValue(value: final list?) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final game in list) ...[
            GameCard(game: game, onTap: () => onOpen(game.id)),
            const SizedBox(height: 12),
          ],
        ],
      ),
      AsyncError(:final error) => ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(gameSummariesProvider(gameIds.join(','))),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}
