import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import 'game_card.dart';
import 'games_providers.dart';

/// "Próximos jogos" do detalhe do grupo (RF26, RF44; docs/ui/telas.md, 7.6;
/// group-jogos.png): os cards dos jogos Abertos e Confirmados do grupo e o
/// botão Criar jogo, com o grupo escolhido. O roteador entrega esta seção à
/// tela do grupo (docs/arquitetura-app.md, seção 2; research R9).
class GroupGamesSection extends ConsumerWidget {
  const GroupGamesSection({required this.groupId, super.key});

  final String groupId;

  /// O que o detalhe do grupo chama ao puxar para baixo.
  static Future<void> refresh(WidgetRef ref, String groupId) =>
      ref.refresh(groupGamesProvider(groupId).future);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final games = ref.watch(groupGamesProvider(groupId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.groupGamesTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        switch (games) {
          AsyncValue(:final value?) when value.isEmpty => Text(
            l10n.groupGamesEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final game in upcomingGames(value)) ...[
                GameCard(
                  game: game,
                  // O detalhe do jogo abre na aba Jogos (telas.md, 7.6).
                  onTap: () => context.goNamed(
                    Routes.game,
                    pathParameters: {'gameId': game.id},
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
          AsyncError(:final error) => Row(
            children: [
              Expanded(
                child: Text(
                  errorTextFor(l10n, error),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(groupGamesProvider(groupId)),
                child: Text(l10n.commonTryAgain),
              ),
            ],
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
        const SizedBox(height: 12),
        // Qualquer membro cria (RN20).
        PrimaryButton(
          label: l10n.gamesCreate,
          onPressed: () async {
            await context.pushNamed(
              Routes.gamesNew,
              queryParameters: {'groupId': groupId},
            );
            if (context.mounted) ref.invalidate(groupGamesProvider(groupId));
          },
        ),
      ],
    );
  }
}
