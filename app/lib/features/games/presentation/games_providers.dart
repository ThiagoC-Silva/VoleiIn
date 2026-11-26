import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/games_repository.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';

// Leituras das telas de jogo (docs/ui/telas.md, seção 7). Meus jogos e os
// jogos do grupo releem ao abrir, ao voltar de outra tela e ao puxar para
// baixo. O detalhe assina o Realtime (docs/arquitetura-app.md, seção 6).

final myGamesProvider = FutureProvider.autoDispose<List<GameSummary>>(
  (ref) => ref.watch(gamesRepositoryProvider).fetchMyGames(),
);

final groupGamesProvider = FutureProvider.autoDispose
    .family<List<GameSummary>, String>(
      (ref, groupId) =>
          ref.watch(gamesRepositoryProvider).fetchGroupGames(groupId),
    );

/// A aba Cobranças e o contador dela (telas.md, 8.5). A barra inferior a
/// mantém viva; ela relê ao tocar na aba e junto com Meus jogos.
final myChargesProvider = FutureProvider.autoDispose<ChargesOverview>(
  (ref) => ref.watch(gamesRepositoryProvider).fetchMyCharges(),
);

/// O Rateio do jogo concluído, relido ao abrir e ao puxar para baixo
/// (docs/ui/telas.md, seção 8).
final gameSplitProvider = FutureProvider.autoDispose.family<GameSplit, String>(
  (ref, gameId) => ref.watch(gamesRepositoryProvider).fetchSplit(gameId),
);

/// O valor a pagar, relido ao abrir e ao puxar para baixo (telas.md, seção 9).
final chargeProvider = FutureProvider.autoDispose.family<ChargeDetail, String>(
  (ref, chargeId) => ref.watch(gamesRepositoryProvider).fetchCharge(chargeId),
);

/// O detalhe do jogo, relido a cada evento do Realtime em `games`,
/// `game_participants` e `game_waitlist` (telas.md, 7.3).
class GameDetailNotifier extends AsyncNotifier<GameDetail> {
  GameDetailNotifier(this.gameId);

  final String gameId;

  @override
  Future<GameDetail> build() async {
    final repository = ref.read(gamesRepositoryProvider);
    final unsubscribe = repository.watchGame(gameId, () {
      if (ref.mounted) ref.invalidateSelf();
    });
    ref.onDispose(unsubscribe);
    return repository.fetchGame(gameId);
  }
}

final gameDetailProvider = AsyncNotifierProvider.autoDispose
    .family<GameDetailNotifier, GameDetail, String>(GameDetailNotifier.new);

/// URL assinada da foto de uma pessoa do jogo, no bucket `avatars`.
final gameAvatarUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, photoPath) => ref.watch(gamesRepositoryProvider).avatarUrl(photoPath),
);

/// Os grupos da sheet da criação (telas.md, 7.2).
final gameGroupOptionsProvider =
    FutureProvider.autoDispose<List<GameGroupOption>>(
      (ref) => ref.watch(gamesRepositoryProvider).fetchMyGroupOptions(),
    );

/// Se quem cria o jogo tem chave Pix (RN22).
final ownHasPixKeyProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(gamesRepositoryProvider).hasPixKey(),
);

/// Ordem dos jogos (telas.md, seção 7): Próximos do início mais cedo para o
/// mais tarde; Anteriores do mais recente para o mais antigo.
List<GameSummary> upcomingGames(List<GameSummary> games) =>
    games.where((game) => game.status.isActive).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

List<GameSummary> pastGames(List<GameSummary> games) =>
    games.where((game) => !game.status.isActive).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

/// Os admins do jogo, com o nome (telas.md, 7.5).
final gameAdminsProvider = FutureProvider.autoDispose
    .family<List<GameAdmin>, String>(
      (ref, gameId) =>
          ref.watch(gamesRepositoryProvider).fetchGameAdmins(gameId),
    );

/// Os cards dos jogos da sheet de bloqueio (telas.md, 7.8).
final gameSummariesProvider = FutureProvider.autoDispose
    .family<List<GameSummary>, String>(
      (ref, ids) =>
          ref.watch(gamesRepositoryProvider).fetchGameSummaries(ids.split(',')),
    );
