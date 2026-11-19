import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/filter_chips.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/game_models.dart';
import 'game_card.dart';
import 'games_providers.dart';

/// Meus jogos (RF44; docs/ui/telas.md, 7.1; games.png, games-anteriores.png
/// e games-vazio.png). Os chips ficam no alto, a lista no meio e o botão
/// Criar jogo fixo no pé. O chip escolhido fica só em memória, enquanto a aba
/// existir.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  /// 0 = Próximos, 1 = Anteriores.
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = ref.watch(myGamesProvider);
    // O contador de Cobranças relê junto com Meus jogos (telas.md, 8.5).
    ref.listen(myGamesProvider, (_, next) {
      if (next.isLoading) ref.invalidate(myChargesProvider);
    });
    Future<void> refresh() => ref.refresh(myGamesProvider.future);

    return RootTabScaffold(
      title: l10n.navGames,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: FilterChipBar(
              labels: [l10n.gamesFilterUpcoming, l10n.gamesFilterPast],
              selected: _filter,
              onSelected: (index) => setState(() => _filter = index),
            ),
          ),
          Expanded(
            child: switch (games) {
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: refresh,
                child: _filtered(value).isEmpty
                    ? _empty(l10n)
                    : _GameList(games: _filtered(value)),
              ),
              AsyncError(:final error) => ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(myGamesProvider),
              ),
              _ => const LoadingState(),
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: PrimaryButton(
              label: l10n.gamesCreate,
              onPressed: () async {
                await context.pushNamed(Routes.gamesNew);
                if (mounted) ref.invalidate(myGamesProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<GameSummary> _filtered(List<GameSummary> games) =>
      _filter == 0 ? upcomingGames(games) : pastGames(games);

  Widget _empty(AppLocalizations l10n) => _filter == 0
      ? EmptyState(
          icon: Symbols.sports_volleyball,
          title: l10n.gamesEmptyUpcomingTitle,
          body: l10n.gamesEmptyUpcomingBody,
        )
      : EmptyState(
          icon: Symbols.history,
          title: l10n.gamesEmptyPastTitle,
          body: l10n.gamesEmptyPastBody,
        );
}

class _GameList extends ConsumerWidget {
  const _GameList({required this.games});

  final List<GameSummary> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => GameCard(
        game: games[index],
        onTap: () async {
          await context.pushNamed(
            Routes.game,
            pathParameters: {'gameId': games[index].id},
          );
          // Relê ao voltar do detalhe (telas.md, seção 7).
          if (context.mounted) ref.invalidate(myGamesProvider);
        },
      ),
    );
  }
}
