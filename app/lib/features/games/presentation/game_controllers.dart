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

/// Entrar e sair da lista e da espera, e remover alguém (telas.md, 7.3).
/// Depois de cada uma, com sucesso ou erro, o jogo é relido: `GAME_FULL`,
/// `GAME_NOT_FULL`, `GAME_NOT_OPEN`, `GAME_STARTED`, `RECEIVER_LOCKED` e
/// `LIST_LOCKED` indicam que os dados mudaram.
class GameActionsController extends SubmitController {
  GamesRepository get _games => ref.read(gamesRepositoryProvider);

  Future<AppException?> join(String gameId) =>
      _run(gameId, () => _games.joinGame(gameId));

  Future<AppException?> joinWaitlist(String gameId) =>
      _run(gameId, () => _games.joinWaitlist(gameId));

  Future<AppException?> leaveWaitlist(String gameId) =>
      _run(gameId, () => _games.leaveWaitlist(gameId));

  /// O `outcome` do servidor, ou o erro.
  Future<(LeaveOutcome?, AppException?)> leave(String gameId) async {
    LeaveOutcome? outcome;
    final error = await _run(gameId, () async {
      outcome = await _games.leaveGame(gameId);
    });
    return (outcome, error);
  }

  Future<AppException?> cancel(String gameId) =>
      _run(gameId, () => _games.cancelGame(gameId));

  Future<AppException?> addAdmin(String gameId, String userId) =>
      _run(gameId, () => _games.addGameAdmin(gameId: gameId, userId: userId));

  Future<AppException?> removeAdmin(String gameId, String userId) => _run(
    gameId,
    () => _games.removeGameAdmin(gameId: gameId, userId: userId),
  );

  /// `change_receiver` (RF33). As cobranças mudam junto, depois da conclusão.
  Future<AppException?> changeReceiver(String gameId, String userId) async {
    final error = await _run(
      gameId,
      () => _games.changeReceiver(gameId: gameId, newReceiverId: userId),
    );
    if (ref.mounted) ref.invalidate(myChargesProvider);
    return error;
  }

  Future<AppException?> remove(String gameId, String userId) => _run(
    gameId,
    () => _games.removeParticipant(gameId: gameId, userId: userId),
  );

  Future<AppException?> _run(
    String gameId,
    Future<void> Function() action,
  ) async {
    final error = await submit(action);
    if (ref.mounted) {
      ref.invalidate(gameDetailProvider(gameId));
      ref.invalidate(gameAdminsProvider(gameId));
      ref.invalidate(myGamesProvider);
    }
    return error;
  }
}

final gameActionsControllerProvider =
    AsyncNotifierProvider.autoDispose<GameActionsController, void>(
      GameActionsController.new,
    );

/// Concluir o jogo e o que o Rateio faz com um valor: isentar, marcar como
/// pago e reverter (docs/ui/telas.md, 8.2, 8.3 e 9.5). Na conclusão, com sucesso ou erro, o jogo e
/// Meus jogos são relidos: `GAME_NOT_OPEN` e as faltas recusadas indicam que
/// os dados mudaram.
class GameCompletionController extends SubmitController {
  Future<AppException?> complete({
    required String gameId,
    required int? totalCents,
    required List<String> absentUserIds,
  }) async {
    final error = await submit(
      () => ref
          .read(gamesRepositoryProvider)
          .completeGame(
            gameId: gameId,
            totalCents: totalCents,
            absentUserIds: absentUserIds,
          ),
    );
    if (ref.mounted) {
      ref.invalidate(gameDetailProvider(gameId));
      ref.invalidate(myGamesProvider);
    }
    return error;
  }

  /// `waive_penalty` (RF64). O Rateio relê depois, pela própria tela; o
  /// detalhe relê o valor de quem lê.
  Future<AppException?> waive({
    required String gameId,
    required String chargeId,
  }) async {
    final error = await submit(
      () => ref.read(gamesRepositoryProvider).waivePenalty(chargeId),
    );
    if (ref.mounted) ref.invalidate(gameDetailProvider(gameId));
    return error;
  }

  /// `mark_charge_paid` (RF84).
  Future<AppException?> markPaid({
    required String gameId,
    required String chargeId,
  }) => _payment(
    gameId,
    () => ref.read(gamesRepositoryProvider).markChargePaid(chargeId),
  );

  /// `revert_charge` (RF85).
  Future<AppException?> revert({
    required String gameId,
    required String chargeId,
  }) => _payment(
    gameId,
    () => ref.read(gamesRepositoryProvider).revertCharge(chargeId),
  );

  /// Com sucesso ou erro, o detalhe e as cobranças releem; o Rateio, pela
  /// própria tela (docs/ui/telas.md, 9.5).
  Future<AppException?> _payment(
    String gameId,
    Future<void> Function() action,
  ) async {
    final error = await submit(action);
    if (ref.mounted) {
      ref.invalidate(gameDetailProvider(gameId));
      ref.invalidate(myChargesProvider);
    }
    return error;
  }
}

final gameCompletionControllerProvider =
    AsyncNotifierProvider.autoDispose<GameCompletionController, void>(
      GameCompletionController.new,
    );
