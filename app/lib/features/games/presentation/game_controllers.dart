import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/submit_controller.dart';
import '../data/games_repository.dart';
import '../domain/game_models.dart';
import 'games_providers.dart';

/// Criar e editar o jogo (docs/ui/telas.md, 7.2 e 7.4).
class GameFormController extends SubmitController {
  GamesRepository get _games => ref.read(gamesRepositoryProvider);

  /// O `game_id` criado, ou o erro.
  Future<(String?, AppException?)> create({
    required String? groupId,
    required GameInput input,
  }) async {
    String? gameId;
    final error = await submit(() async {
      gameId = await _games.createGame(groupId: groupId, input: input);
    });
    if (ref.mounted) {
      ref.invalidate(myGamesProvider);
      if (groupId != null) ref.invalidate(groupGamesProvider(groupId));
      // Os dados que podem ter mudado em outro aparelho (telas.md, 7.2).
      if (error.hasCode(ErrorCode.receiverNeedsPixKey)) {
        ref.invalidate(ownHasPixKeyProvider);
      }
      if (error.hasCode(ErrorCode.notFound)) {
        ref.invalidate(gameGroupOptionsProvider);
      }
    }
    return (gameId, error);
  }

  /// Nesta ordem: `set_slot_limit`, se o limite mudou; `update_game`, se
  /// algum outro dado mudou (telas.md, 7.4). Sem mudança, nada é chamado.
  Future<AppException?> save({
    required String gameId,
    required int? newSlotLimit,
    required GameInput? input,
  }) async {
    final error = await submit(() async {
      if (newSlotLimit != null) {
        await _games.setSlotLimit(gameId: gameId, slotLimit: newSlotLimit);
      }
      if (input != null) await _games.updateGame(gameId: gameId, input: input);
    });
    if (ref.mounted) {
      // Com sucesso ou erro: o limite pode já valer, e um erro como
      // SLOT_LIMIT_BELOW_PARTICIPANTS indica que os dados mudaram.
      ref.invalidate(gameDetailProvider(gameId));
      ref.invalidate(myGamesProvider);
    }
    return error;
  }
}

final gameFormControllerProvider =
    AsyncNotifierProvider.autoDispose<GameFormController, void>(
      GameFormController.new,
    );

/// Entrar na lista e na espera (telas.md, 7.3). Depois de cada uma, com
/// sucesso ou erro, o jogo é relido: `GAME_FULL`, `GAME_NOT_FULL`,
/// `GAME_NOT_OPEN` e `GAME_STARTED` indicam que os dados mudaram.
class GameActionsController extends SubmitController {
  GamesRepository get _games => ref.read(gamesRepositoryProvider);

  Future<AppException?> join(String gameId) =>
      _run(gameId, () => _games.joinGame(gameId));

  Future<AppException?> joinWaitlist(String gameId) =>
      _run(gameId, () => _games.joinWaitlist(gameId));

  Future<AppException?> _run(
    String gameId,
    Future<void> Function() action,
  ) async {
    final error = await submit(action);
    if (ref.mounted) {
      ref.invalidate(gameDetailProvider(gameId));
      ref.invalidate(myGamesProvider);
    }
    return error;
  }
}

final gameActionsControllerProvider =
    AsyncNotifierProvider.autoDispose<GameActionsController, void>(
      GameActionsController.new,
    );
