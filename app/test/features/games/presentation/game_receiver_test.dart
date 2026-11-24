import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S72, S73, S75 e S76 da etapa C de docs/testes-referencia.md,
/// seção 13 (docs/ui/telas.md, 8.1 e 8.4; game-trocarRecebedor.png): a troca
/// de recebedor pelo menu do admin.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  void stubChange(Future<void> Function() answer) {
    when(
      () => h.games.changeReceiver(
        gameId: any(named: 'gameId'),
        newReceiverId: any(named: 'newReceiverId'),
      ),
    ).thenAnswer((_) => answer());
  }

  /// Quantas vezes o detalhe leu o jogo.
  var reads = 0;

  void game(GameDetail Function() read) {
    reads = 0;
    h.game(() {
      reads++;
      return read();
    });
  }

  Future<void> tapFinder(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  Future<void> openDetail(
    WidgetTester tester,
    String gameId, {
    double textScale = 1,
  }) async {
    await h.pumpApp(tester, location: '/games', textScale: textScale);
    await h.push(tester, '/games/$gameId');
  }

  Future<void> openMenu(WidgetTester tester) =>
      tapFinder(tester, find.byTooltip(l10nPt.gameMenuLabel));

  Future<void> openSheet(WidgetTester tester) async {
    await openMenu(tester);
    await tapText(tester, l10nPt.gameChangeReceiver);
  }

  /// O jogo 1 antes do início: Ana (recebedora), Brunão, Carlinha e Edu, que
  /// saiu depois do início.
  GameDetail s72Game() => game1(
    participants: [
      ...game1Participants(),
      participant(
        edId,
        'Edu',
        minute: 12,
        status: ParticipantStatus.leftAfterStart,
      ),
    ],
  );

  group('Menu do admin (telas.md, 8.1)', () {
    testWidgets('Trocar recebedor no jogo Aberto e no concluído', (
      tester,
    ) async {
      game(() => game1());
      await openDetail(tester, game1Id);
      await openMenu(tester);
      expect(find.text(l10nPt.gameChangeReceiver), findsOneWidget);
    });

    testWidgets('no concluído, com Admins do jogo', (tester) async {
      game(() => completedGame());
      await openDetail(tester, finishedId);
      await openMenu(tester);
      expect(find.text(l10nPt.gameChangeReceiver), findsOneWidget);
      expect(find.text(l10nPt.gameAdmins), findsOneWidget);
    });

    testWidgets('sem Trocar recebedor no jogo cancelado', (tester) async {
      game(() => game1(status: GameStatus.cancelled));
      await openDetail(tester, game1Id);
      await openMenu(tester);
      expect(find.text(l10nPt.gameChangeReceiver), findsNothing);
    });
  });

  group('S72: troca antes do início', () {
    testWidgets('lista sem a Ana e sem o Edu; troca para a Carlinha', (
      tester,
    ) async {
      game(s72Game);
      stubChange(() async {});
      await openDetail(tester, game1Id);
      await openSheet(tester);

      expect(inSheet(find.text(l10nPt.gameChangeReceiver)), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsOneWidget);
      expect(inSheet(find.text('Brunão')), findsOneWidget);
      expect(inSheet(find.text('Carlinha')), findsOneWidget);
      expect(inSheet(find.text('Ana')), findsNothing);
      expect(inSheet(find.text('Edu')), findsNothing);
      // Brunão antes da Carlinha, pela ordem de entrada.
      expect(
        tester.getTopLeft(inSheet(find.text('Brunão'))).dy,
        lessThan(tester.getTopLeft(inSheet(find.text('Carlinha'))).dy),
      );

      final readsBefore = reads;
      await tapFinder(tester, inSheet(find.text('Carlinha')));
      expect(
        find.text(l10nPt.receiverChangeConfirmTitle('Carlinha')),
        findsOneWidget,
      );
      await tapText(tester, l10nPt.receiverChangeConfirmAction);

      verify(
        () => h.games.changeReceiver(gameId: game1Id, newReceiverId: carlaId),
      ).called(1);
      expect(find.text('Carlinha agora é o recebedor.'), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsNothing);
      expect(reads, greaterThan(readsBefore));
    });

    testWidgets('Voltar na confirmação não troca', (tester) async {
      game(s72Game);
      stubChange(() async {});
      await openDetail(tester, game1Id);
      await openSheet(tester);
      await tapFinder(tester, inSheet(find.text('Brunão')));
      await tapText(tester, l10nPt.commonBack);

      verifyNever(
        () => h.games.changeReceiver(
          gameId: any(named: 'gameId'),
          newReceiverId: any(named: 'newReceiverId'),
        ),
      );
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsOneWidget);
    });

    testWidgets('RECEIVER_NEEDS_PIX_KEY: SnackBar, com a sheet aberta', (
      tester,
    ) async {
      game(s72Game);
      stubChange(
        () async => throw const AppException(ErrorCode.receiverNeedsPixKey),
      );
      await openDetail(tester, game1Id);
      await openSheet(tester);
      await tapFinder(tester, inSheet(find.text('Carlinha')));
      await tapText(tester, l10nPt.receiverChangeConfirmAction);

      expect(find.text(l10nPt.errorReceiverNeedsPixKey), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsOneWidget);
    });

    testWidgets('RECEIVER_MUST_BE_PARTICIPANT: SnackBar, fecha e relê', (
      tester,
    ) async {
      game(s72Game);
      stubChange(
        () async =>
            throw const AppException(ErrorCode.receiverMustBeParticipant),
      );
      await openDetail(tester, game1Id);
      await openSheet(tester);
      final readsBefore = reads;
      await tapFinder(tester, inSheet(find.text('Carlinha')));
      await tapText(tester, l10nPt.receiverChangeConfirmAction);

      expect(find.text(l10nPt.errorReceiverMustBeParticipant), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsNothing);
      expect(reads, greaterThan(readsBefore));
    });
  });

  group('S73: troca depois da conclusão', () {
    testWidgets('receiverChangeAfterBody', (tester) async {
      game(() => completedGame());
      await openDetail(tester, finishedId);
      await openSheet(tester);

      expect(find.text(l10nPt.receiverChangeAfterBody), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeBeforeBody), findsNothing);
      expect(inSheet(find.text('Fábio')), findsOneWidget);
    });

    // Sem rodapé no jogo concluído, nada observava o controller: ele era
    // descartado durante a chamada e o detalhe não relia (bug achado no L22).
    testWidgets('a troca relê o detalhe e Cobranças, sem o Realtime', (
      tester,
    ) async {
      game(() => completedGame());
      stubChange(() => Future.delayed(const Duration(milliseconds: 300)));
      await openDetail(tester, finishedId);
      await openSheet(tester);
      await tapFinder(tester, inSheet(find.text('Fábio')));
      final readsBefore = reads;
      clearInteractions(h.games);
      await tapText(tester, l10nPt.receiverChangeConfirmAction);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.receiverChanged('Fábio')), findsOneWidget);
      expect(reads, greaterThan(readsBefore));
      verify(() => h.games.fetchMyCharges()).called(greaterThanOrEqualTo(1));
    });

    testWidgets('RECEIVER_CHANGE_BLOCKED: SnackBar, e a sheet fecha', (
      tester,
    ) async {
      game(() => completedGame());
      stubChange(
        () async => throw const AppException(ErrorCode.receiverChangeBlocked),
      );
      await openDetail(tester, finishedId);
      await openSheet(tester);
      await tapFinder(tester, inSheet(find.text('Fábio')));
      await tapText(tester, l10nPt.receiverChangeConfirmAction);

      expect(find.text(l10nPt.errorReceiverChangeBlocked), findsOneWidget);
      expect(find.text(l10nPt.receiverChangeAfterBody), findsNothing);
    });

    testWidgets('só a Ana na lista: receiverChangeEmpty', (tester) async {
      game(
        () => finishedGame(
          status: GameStatus.completed,
          shareCents: 2084,
          participants: [participant(anaId, 'Ana')],
        ),
      );
      await openDetail(tester, finishedId);
      await openSheet(tester);

      expect(find.text(l10nPt.receiverChangeEmpty), findsOneWidget);
    });
  });

  group('S75: fonte em 150%', () {
    testWidgets('sheet e confirmação da troca, sem overflow', (tester) async {
      game(() => completedGame());
      await openDetail(tester, finishedId, textScale: 1.5);
      await openSheet(tester);
      expect(tester.takeException(), isNull);
      await tapFinder(tester, inSheet(find.text('Fábio')));
      expect(tester.takeException(), isNull);
    });
  });

  group('S76: TalkBack', () {
    testWidgets('linhas da sheet com rótulo e 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      game(s72Game);
      await openDetail(tester, game1Id);
      await openSheet(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
