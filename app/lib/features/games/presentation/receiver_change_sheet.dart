import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/snack.dart';
import '../domain/game_models.dart';
import 'game_controllers.dart';
import 'games_providers.dart';

/// Trocar recebedor (RF33, RN30, RN31; docs/ui/telas.md, 8.4;
/// game-trocarRecebedor.png): sheet sobre o detalhe, aberta pelo menu do
/// admin, com uma linha por passagem `active`, exceto o recebedor atual. O app
/// não sabe quem tem chave Pix: o servidor recusa quem não tem
/// (`RECEIVER_NEEDS_PIX_KEY`), e a sheet continua aberta.
Future<void> showReceiverChangeSheet(BuildContext context, GameDetail game) =>
    showVoleiSheet<void>(context, (_) => _ReceiverChangeSheet(game: game));

class _ReceiverChangeSheet extends ConsumerWidget {
  const _ReceiverChangeSheet({required this.game});

  final GameDetail game;

  /// A confirmação e `change_receiver`. O detalhe relê pelo controller, com
  /// sucesso ou erro.
  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    GameParticipant person,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.receiverChangeConfirmTitle(person.displayName),
      confirmLabel: l10n.receiverChangeConfirmAction,
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(gameActionsControllerProvider.notifier)
        .changeReceiver(game.id, person.userId);
    if (!context.mounted) return;
    if (error == null) {
      showSnack(context, l10n.receiverChanged(person.displayName));
    } else {
      showErrorSnack(context, error);
      // Sem chave Pix: dá para escolher outra pessoa.
      if (error.code == ErrorCode.receiverNeedsPixKey) return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final candidates =
        game.participants
            .where(
              (p) =>
                  p.status == ParticipantStatus.active &&
                  p.userId != game.receiverId,
            )
            .toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.gameChangeReceiver, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          game.status == GameStatus.completed
              ? l10n.receiverChangeAfterBody
              : l10n.receiverChangeBeforeBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (candidates.isEmpty)
          Text(l10n.receiverChangeEmpty, style: theme.textTheme.bodyLarge)
        else
          ListCard(
            children: [
              for (final person in candidates)
                ListRow(
                  leading: _Avatar(person: person),
                  title: person.displayName,
                  showChevron: true,
                  onTap: () => _choose(context, ref, person),
                ),
            ],
          ),
      ],
    );
  }
}

class _Avatar extends ConsumerWidget {
  const _Avatar({required this.person});

  final GameParticipant person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = person.photoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return VoleiAvatar(
      id: person.userId,
      name: person.displayName,
      imageUrl: url,
    );
  }
}
