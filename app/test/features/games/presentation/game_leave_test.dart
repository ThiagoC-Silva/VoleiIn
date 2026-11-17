import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S43 a S47 de docs/testes-referencia.md, seção 12.6, e a remoção
/// pelo admin (docs/ui/telas.md, 7.3; game-sair.png, game-espera.png,
/// game-participante.png e game-andamento.png). Etapa B da fatia 4. O S46
/// (`GAME_FULL` ao entrar) já está em game_screen_test.dart, da etapa A.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn(userId: brunoId);
    when(() => h.games.joinGame(any())).thenAnswer((_) async {});
    when(() => h.games.leaveWaitlist(any())).thenAnswer((_) async {});
    when(() => h.games.leaveGame(any()))
        .thenAnswer((_) async => LeaveOutcome.cancelledOnTime);
    when(
      () => h.games.removeParticipant(
        gameId: any(named: 'gameId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester, String gameId) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$gameId');
  }

  Future<void> tapButton<T extends ButtonStyleButton>(
    WidgetTester tester,
    String label,
  ) async {
    final button = buttonWithText<T>(label).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('S43: Bruno sai da lista', () {
    testWidgets('antes do prazo: confirmação e gameLeftOnTime', (tester) async {
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.gameLeaveTitle), findsOneWidget);
      expect(find.textContaining('Saindo até'), findsOneWidget);
      verifyNever(() => h.games.leaveGame(any()));

      await tapButton<FilledButton>(tester, l10nPt.gameLeave);
      verify(() => h.games.leaveGame(game1Id)).called(1);
      expect(find.text(l10nPt.gameLeftOnTime), findsOneWidget);
    });

    testWidgets('o SnackBar segue o outcome do servidor, e não o relógio', (
      tester,
    ) async {
      when(() => h.games.leaveGame(any()))
          .thenAnswer((_) async => LeaveOutcome.cancelledLate);
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      await tapButton<FilledButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.gameLeftLate), findsOneWidget);
    });

    testWidgets('Voltar não chama leave_game', (tester) async {
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      await tapButton<OutlinedButton>(tester, l10nPt.commonBack);
      verifyNever(() => h.games.leaveGame(any()));
    });

    testWidgets('entre o prazo e o início: gameLeaveLateBody', (tester) async {
      h.now = DateTime.utc(2026, 11, 21, 12);
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.gameLeaveLateBody), findsOneWidget);
    });

    testWidgets('RECEIVER_LOCKED: SnackBar e relê', (tester) async {
      when(() => h.games.leaveGame(any()))
          .thenThrow(const AppException(ErrorCode.receiverLocked));
      var reads = 0;
      h.game(() {
        reads++;
        return game1(viewerId: brunoId);
      });
      await open(tester, game1Id);
      final before = reads;

      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      await tapButton<FilledButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.errorReceiverLocked), findsOneWidget);
      expect(reads, greaterThan(before));
    });
  });

  testWidgets('S44 (saída): a recebedora não tem Sair da lista', (
    tester,
  ) async {
    h.signedIn();
    h.game(game1);
    await open(tester, game1Id);

    expect(find.text(l10nPt.gameReceiverCannotLeave), findsOneWidget);
    expect(find.text(l10nPt.gameLeave), findsNothing);
  });

  group('S45: Bruno na espera', () {
    testWidgets('2º na espera, jogo Confirmado', (tester) async {
      h.game(
        () => game2(
          viewerId: brunoId,
          waitlist: [
            waiting(edId, 'Edu'),
            waiting(brunoId, 'Brunão', minute: 5),
          ],
        ),
      );
      await open(tester, game2Id);

      expect(find.text(l10nPt.gameWaitlistNotice('2')), findsOneWidget);
      await tapButton<OutlinedButton>(tester, l10nPt.gameLeaveWaitlist);
      verify(() => h.games.leaveWaitlist(game2Id)).called(1);
      expect(find.text(l10nPt.gameLeftWaitlist), findsOneWidget);
    });

    testWidgets('jogo Aberto: Entrar na lista e Sair da lista de espera', (
      tester,
    ) async {
      h.game(
        () => game1(
          viewerId: brunoId,
          participants: [participant(anaId, 'Ana')],
          waitlist: [waiting(brunoId, 'Brunão')],
        ),
      );
      await open(tester, game1Id);

      expect(buttonWithText<FilledButton>(l10nPt.gameJoin), findsOneWidget);
      await tapButton<TextButton>(tester, l10nPt.gameLeaveWaitlist);
      verify(() => h.games.leaveWaitlist(game1Id)).called(1);
    });
  });

  group('S47: tempo', () {
    testWidgets('em andamento: selo e gameLeaveAfterStartBody', (tester) async {
      when(() => h.games.leaveGame(any()))
          .thenAnswer((_) async => LeaveOutcome.leftAfterStart);
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameInProgress), findsOneWidget);
      await tapButton<OutlinedButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.gameLeaveAfterStartBody), findsOneWidget);
      await tapButton<FilledButton>(tester, l10nPt.gameLeave);
      expect(find.text(l10nPt.gameLeftAfterStart), findsOneWidget);
    });

    testWidgets('depois do fim: aguardando conclusão, sem botão', (
      tester,
    ) async {
      h.now = DateTime.utc(2026, 11, 22, 2);
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameAwaitingCompletion), findsOneWidget);
      expect(find.text(l10nPt.gameListLocked), findsOneWidget);
      expect(find.text(l10nPt.gameLeave), findsNothing);
    });

    testWidgets('saiu após o início: sem pé', (tester) async {
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(
        () => game1(
          viewerId: brunoId,
          participants: [
            participant(anaId, 'Ana'),
            participant(
              brunoId,
              'Brunão',
              minute: 5,
              status: ParticipantStatus.leftAfterStart,
            ),
          ],
        ),
      );
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameLeave), findsNothing);
    });
  });

  group('remover da lista (admin)', () {
    testWidgets('sheet, confirmação, remove_participant e SnackBar', (
      tester,
    ) async {
      h.signedIn();
      h.game(game1);
      await open(tester, game1Id);

      await tester.ensureVisible(find.text('Brunão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brunão'));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.groupMemberViewProfile), findsOneWidget);

      await tester.tap(find.text(l10nPt.gameParticipantRemove));
      await tester.pumpAndSettle();
      expect(
        find.text(l10nPt.gameParticipantRemoveTitle('Brunão')),
        findsOneWidget,
      );
      expect(
        find.text(l10nPt.gameParticipantRemoveBody('Brunão')),
        findsOneWidget,
      );

      await tapButton<FilledButton>(
        tester,
        l10nPt.gameParticipantRemoveConfirm,
      );
      verify(() => h.games.removeParticipant(gameId: game1Id, userId: brunoId))
          .called(1);
      expect(
        find.text(l10nPt.gameParticipantRemoved('Brunão')),
        findsOneWidget,
      );
    });

    testWidgets('depois do início, o toque abre o perfil, sem sheet', (
      tester,
    ) async {
      h.signedIn();
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(game1);
      await open(tester, game1Id);

      await tester.ensureVisible(find.text('Brunão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brunão'));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.gameParticipantRemove), findsNothing);
      expect(h.location, '/games/$game1Id/people/$brunoId');
    });
  });
}
