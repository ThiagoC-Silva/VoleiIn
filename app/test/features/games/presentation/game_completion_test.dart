import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S61 a S66, S68, S69 (sem Isentos), S75 e S76 da etapa A de
/// docs/testes-referencia.md, seção 13 (docs/ui/telas.md, 8.1 a 8.3;
/// game-aguardando.png, game-concluido.png, gameComplete.png,
/// gameComplete-vagas.png, gameComplete-confirmar.png, gameSplit.png e
/// gameSplit-recebedor.png). As faltas, o histórico e a isenção são da etapa
/// B; a troca de recebedor e Cobranças, da etapa C.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  void stubPreview(Future<CompletionPreview> Function() answer) {
    when(
      () => h.games.previewCompleteGame(
        gameId: any(named: 'gameId'),
        totalCents: any(named: 'totalCents'),
        absentUserIds: any(named: 'absentUserIds'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> openDetail(WidgetTester tester, String gameId) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$gameId');
  }

  Future<void> openComplete(WidgetTester tester) async {
    await openDetail(tester, finishedId);
    await h.push(tester, '/games/$finishedId/complete');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<List<String>> menuOptions(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10nPt.gameMenuLabel));
    await tester.pumpAndSettle();
    final items = tester
        .widgetList<PopupMenuItem<Object?>>(
          find.byWidgetPredicate((w) => w is PopupMenuItem),
        )
        .length;
    final labels = [
      l10nPt.gameEdit,
      l10nPt.gameComplete,
      l10nPt.gameAdmins,
      l10nPt.gameCancel,
    ].where((label) => find.text(label).evaluate().isNotEmpty).toList();
    expect(labels.length, lessThanOrEqualTo(items));
    return labels;
  }

  group('S61: detalhe do jogo concluído', () {
    testWidgets('visto por Bruno, com share Pendente', (tester) async {
      h.signedIn(userId: brunoId);
      h.game(
        () => completedGame(
          viewerId: brunoId,
          myCharge: charge(brunoId, 'Brunão'),
        ),
      );
      await openDetail(tester, finishedId);

      expect(find.text(l10nPt.gameStatusCompleted), findsOneWidget);
      expect(find.text(l10nPt.gameAwaitingCompletion), findsNothing);
      expect(find.text('10/12'), findsWidgets);
      expect(find.text(l10nPt.gameSharePerSlot), findsOneWidget);
      expect(find.text(formatCents(2084)), findsWidgets);
      expect(find.text(formatCents(25000)), findsOneWidget);
      expect(find.text(l10nPt.gameTrioDeadline), findsNothing);
      expect(find.text(l10nPt.splitCardTitle), findsOneWidget);
      expect(find.text(l10nPt.chargeKindShare), findsOneWidget);
      expect(find.text(l10nPt.chargeStatusPending), findsOneWidget);
      expect(find.text(l10nPt.gameAbsentBadge), findsOneWidget);
      expect(find.text(l10nPt.gameLeftAfterStartBadge), findsNothing);
      // Sem pé.
      expect(find.text(l10nPt.gameListLocked), findsNothing);
      expect(find.text(l10nPt.gameComplete), findsNothing);
      expect(find.byTooltip(l10nPt.gameMenuLabel), findsNothing);
    });

    testWidgets('o card Rateio abre o Rateio', (tester) async {
      h.signedIn(userId: brunoId);
      h.game(
        () => completedGame(
          viewerId: brunoId,
          myCharge: charge(brunoId, 'Brunão'),
        ),
      );
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(viewerId: brunoId),
          charges: [charge(brunoId, 'Brunão')],
          passages: const [],
        ),
      );
      await openDetail(tester, finishedId);
      await tapText(tester, l10nPt.splitCardTitle);

      expect(h.location, '/games/$finishedId/split');
    });

    testWidgets('sem valor: splitNoCharge no card', (tester) async {
      h.game(() => completedGame());
      await openDetail(tester, finishedId);

      expect(find.text(l10nPt.splitNoCharge), findsOneWidget);
    });

    testWidgets('menu da Ana: só Admins do jogo (Trocar recebedor é da '
        'etapa C)', (tester) async {
      h.game(() => completedGame());
      await openDetail(tester, finishedId);

      expect(await menuOptions(tester), [l10nPt.gameAdmins]);
    });
  });

  group('S62: jogo Aberto depois do fim', () {
    testWidgets('Ana: Concluir jogo com gameCompleteHint e no menu', (
      tester,
    ) async {
      h.game(() => finishedGame());
      await openDetail(tester, finishedId);

      expect(find.text(l10nPt.gameAwaitingCompletion), findsOneWidget);
      expect(find.text(l10nPt.gameCompleteHint), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.gameComplete),
        findsOneWidget,
      );
      expect(find.text(l10nPt.gameListLocked), findsNothing);
      expect(await menuOptions(tester), [
        l10nPt.gameComplete,
        l10nPt.gameAdmins,
        l10nPt.gameCancel,
      ]);
    });

    testWidgets('o botão abre a conclusão', (tester) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      await openDetail(tester, finishedId);
      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameComplete));
      await tester.pumpAndSettle();

      expect(h.location, '/games/$finishedId/complete');
    });

    testWidgets('Bruno: o aviso gameListLocked', (tester) async {
      h.signedIn(userId: brunoId);
      h.game(() => finishedGame(viewerId: brunoId));
      await openDetail(tester, finishedId);

      expect(find.text(l10nPt.gameListLocked), findsOneWidget);
      expect(find.text(l10nPt.gameComplete), findsNothing);
    });

    testWidgets('antes do fim, sem a opção no menu', (tester) async {
      h.game(() => game1());
      await openDetail(tester, game1Id);

      expect(await menuOptions(tester), isNot(contains(l10nPt.gameComplete)));
    });
  });

  group('S63: abrir e mudar o total', () {
    testWidgets('preview com total nulo, resumo do R01', (tester) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      await openComplete(tester);

      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [],
        ),
      ).called(1);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('completeTotalField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '250,00');
      expect(find.text(l10nPt.completeTotalHint), findsOneWidget);
      expect(find.text(formatCents(2084)), findsOneWidget);
      expect(find.text(formatCents(22924)), findsOneWidget);
      expect(find.text(l10nPt.splitReceiverCovers('Ana')), findsOneWidget);
      expect(find.text(formatCents(2076)), findsOneWidget);
      expect(find.text(l10nPt.completeExemptedCount(1)), findsOneWidget);
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isTrue);
    });

    testWidgets('novo preview 400 ms depois; botão desabilitado enquanto '
        'carrega e depois da falha', (tester) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      await openComplete(tester);

      final pending = Completer<CompletionPreview>();
      stubPreview(() => pending.future);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('completeTotalField')),
          matching: find.byType(EditableText),
        ),
        '30000',
      );
      await tester.pump(const Duration(milliseconds: 399));
      verifyNever(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: 30000,
          absentUserIds: const [],
        ),
      );
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isFalse);

      await tester.pump(const Duration(milliseconds: 2));
      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: 30000,
          absentUserIds: const [],
        ),
      ).called(1);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isFalse);

      pending.completeError(const AppException(ErrorCode.noConnection));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.commonTryAgain), findsOneWidget);
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isFalse);

      stubPreview(() async => r01Preview);
      await tapText(tester, l10nPt.commonTryAgain);
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isTrue);
    });
  });

  testWidgets('S64: preview do R06 com o aviso das vagas', (tester) async {
    h.game(() => finishedGame());
    stubPreview(
      () async => const CompletionPreview(
        shareCents: 2430,
        totalToReceiveCents: 12150,
        receiverCoveredCents: 14580,
        uncoveredSlots: 6,
        penaltiesExempted: 0,
      ),
    );
    await openComplete(tester);

    expect(
      find.text('6 vagas ficaram sem ninguém. R\$${nbsp}145,80 fica por '
          'conta de Ana.'),
      findsOneWidget,
    );
    expect(find.textContaining('isentada'), findsNothing);
  });

  testWidgets('S65: preview do R04, sem sinal de menos', (tester) async {
    h.game(() => finishedGame());
    stubPreview(
      () async => const CompletionPreview(
        shareCents: 3334,
        totalToReceiveCents: 10002,
        receiverCoveredCents: -8,
        uncoveredSlots: 0,
        penaltiesExempted: 0,
      ),
    );
    await openComplete(tester);

    expect(
      find.text('Ana recebe R\$${nbsp}0,08 a mais que o total, pelo '
          'arredondamento.'),
      findsOneWidget,
    );
    expect(find.textContaining('-'), findsNothing);
  });

  group('S66: concluir', () {
    void stubComplete(Future<CompletionPreview> Function() answer) {
      when(
        () => h.games.completeGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      ).thenAnswer((_) => answer());
    }

    testWidgets('confirmar: complete_game, gameCompleted e o Rateio', (
      tester,
    ) async {
      var completed = false;
      h.game(() => completed ? completedGame() : finishedGame());
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(),
          charges: [charge(brunoId, 'Brunão')],
          passages: const [],
        ),
      );
      stubPreview(() async => r01Preview);
      stubComplete(() async {
        completed = true;
        return r01Preview;
      });
      await openComplete(tester);

      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameComplete));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.completeConfirmTitle), findsOneWidget);
      expect(find.text(l10nPt.completeConfirmBody), findsOneWidget);
      await tapText(tester, l10nPt.completeConfirmAction);

      verify(
        () => h.games.completeGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [],
        ),
      ).called(1);
      expect(find.text(l10nPt.gameCompleted), findsOneWidget);
      expect(h.location, '/games/$finishedId/split');

      await tester.tap(find.byTooltip(l10nPt.commonBack).first);
      await tester.pumpAndSettle();
      expect(h.location, '/games/$finishedId');
    });

    testWidgets('Voltar na confirmação não conclui', (tester) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      stubComplete(() async => r01Preview);
      await openComplete(tester);

      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameComplete));
      await tester.pumpAndSettle();
      await tapText(tester, l10nPt.commonBack);

      verifyNever(
        () => h.games.completeGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      );
      expect(h.location, '/games/$finishedId/complete');
    });

    testWidgets('GAME_NOT_OPEN: SnackBar e volta ao detalhe', (tester) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      stubComplete(
        () async => throw const AppException(ErrorCode.gameNotOpen),
      );
      await openComplete(tester);

      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameComplete));
      await tester.pumpAndSettle();
      await tapText(tester, l10nPt.completeConfirmAction);

      expect(find.text(l10nPt.errorGameNotOpen), findsOneWidget);
      expect(h.location, '/games/$finishedId');
    });

    testWidgets('total apagado: gameTotalRequired, sem chamar o servidor', (
      tester,
    ) async {
      h.game(() => finishedGame());
      stubPreview(() async => r01Preview);
      stubComplete(() async => r01Preview);
      await openComplete(tester);
      clearInteractions(h.games);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('completeTotalField')),
          matching: find.byType(EditableText),
        ),
        '',
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.gameTotalRequired), findsOneWidget);
      verifyNever(
        () => h.games.previewCompleteGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      );
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isFalse);
    });

    testWidgets('sem ser admin, ou concluído: não encontrado', (tester) async {
      h.signedIn(userId: brunoId);
      h.game(() => finishedGame(viewerId: brunoId));
      stubPreview(() async => r01Preview);
      await openComplete(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      verifyNever(
        () => h.games.previewCompleteGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      );
    });

    testWidgets('as faltas de saída após o início vão no preview', (
      tester,
    ) async {
      h.game(
        () => finishedGame(
          participants: [
            ...r01Participants(eduAbsent: false),
            participant(
              daviId,
              'Davi',
              minute: 30,
              status: ParticipantStatus.leftAfterStart,
            ).copyWith(absent: true),
          ],
        ),
      );
      stubPreview(() async => r01Preview);
      await openComplete(tester);

      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [daviId],
        ),
      ).called(1);
    });
  });

  group('S68: Rateio de quem participa', () {
    testWidgets('Bruno com share Pendente: Seu valor, sem totais', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      h.game(() => completedGame(viewerId: brunoId));
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(viewerId: brunoId),
          charges: [charge(brunoId, 'Brunão')],
          passages: const [],
        ),
      );
      await openDetail(tester, finishedId);
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.splitYourValue), findsOneWidget);
      expect(find.text(l10nPt.chargeKindShare), findsOneWidget);
      expect(find.text(formatCents(2084)), findsWidgets);
      expect(find.text(l10nPt.chargeStatusPending), findsOneWidget);
      expect(find.text(l10nPt.splitOwedTo('Ana')), findsOneWidget);
      expect(find.text(l10nPt.splitReceived), findsNothing);
      expect(find.text(l10nPt.splitCharges), findsNothing);
    });

    testWidgets('Davi, que cancelou no prazo: splitNoChargeOnTime', (
      tester,
    ) async {
      h.signedIn(userId: daviId);
      h.game(() => completedGame(viewerId: daviId));
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(viewerId: daviId),
          charges: const [],
          passages: [
            GamePassage(
              userId: daviId,
              displayName: 'Davi',
              status: ParticipantStatus.cancelled,
              joinedAt: DateTime.utc(2026, 11, 14),
            ),
          ],
        ),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.splitNoChargeOnTime), findsOneWidget);
    });

    testWidgets('Fábio, isento na conclusão: splitNoChargeExempt', (
      tester,
    ) async {
      h.signedIn(userId: fabioId);
      h.game(() => completedGame(viewerId: fabioId));
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(viewerId: fabioId),
          charges: const [],
          passages: [
            GamePassage(
              userId: fabioId,
              displayName: 'Fábio',
              status: ParticipantStatus.cancelled,
              joinedAt: DateTime.utc(2026, 11, 14),
              lateCancellation: true,
              lateCancellationExempt: true,
            ),
          ],
        ),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.splitNoChargeExempt), findsOneWidget);
    });

    testWidgets('jogo não concluído: não encontrado', (tester) async {
      h.game(() => finishedGame());
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => throw const AppException(ErrorCode.notFound),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
    });
  });

  group('S69: Rateio da recebedora (sem Isentos)', () {
    GameSplit r08Split({String otherReceiverFor = ''}) {
      final payers = [
        (brunoId, 'Brunão'),
        (eduId, 'Edu'),
        ..._others,
      ];
      return GameSplit(
        game: completedGame(),
        charges: [
          for (final (id, name) in payers)
            id == otherReceiverFor
                ? charge(id, name, receiverId: carlaId, receiverName: 'Carlinha')
                : charge(id, name),
        ],
        passages: [
          GamePassage(
            userId: fabioId,
            displayName: 'Fábio',
            status: ParticipantStatus.cancelled,
            joinedAt: DateTime.utc(2026, 11, 14),
            lateCancellation: true,
            lateCancellationExempt: true,
          ),
        ],
      );
    }

    testWidgets('totais, 10 valores e Sem valor a pagar', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.splitReceived), findsOneWidget);
      expect(find.text(formatCents(0)), findsOneWidget);
      expect(find.text(formatCents(20840)), findsOneWidget);
      expect(find.text(l10nPt.splitReceiverCovers('Ana')), findsOneWidget);
      expect(find.text(formatCents(4160)), findsWidgets);
      expect(find.text(l10nPt.splitCharges), findsOneWidget);
      expect(find.text(l10nPt.chargeStatusPending), findsNWidgets(10));
      expect(find.text(l10nPt.splitWaived), findsNothing);
      expect(find.text(l10nPt.splitNoChargeSection), findsOneWidget);
      expect(find.text(l10nPt.historyExempt), findsOneWidget);
      expect(find.text(l10nPt.gameReceiver), findsOneWidget);
    });

    testWidgets('Para {nome} no valor de outro recebedor', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split(otherReceiverFor: eduId));
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      expect(find.text(l10nPt.splitOwedTo('Carlinha')), findsOneWidget);
      expect(find.text(l10nPt.splitOwedTo('Ana')), findsNothing);
    });
  });

  group('S75: fonte em 150%', () {
    testWidgets('detalhe concluído, conclusão e Rateio sem overflow', (
      tester,
    ) async {
      h.game(() => finishedGame());
      stubPreview(
        () async => const CompletionPreview(
          shareCents: 2430,
          totalToReceiveCents: 12150,
          receiverCoveredCents: 14580,
          uncoveredSlots: 6,
          penaltiesExempted: 2,
        ),
      );
      await h.pumpApp(tester, location: '/games', textScale: 1.5);
      await h.push(tester, '/games/$finishedId');
      expect(tester.takeException(), isNull);
      await h.push(tester, '/games/$finishedId/complete');
      expect(tester.takeException(), isNull);
      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameComplete));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rateio da recebedora e detalhe concluído', (tester) async {
      h.game(() => completedGame(myCharge: null));
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(),
          charges: [
            charge(brunoId, 'Brunão'),
            charge(
              eduId,
              'Edu',
              kind: ChargeKind.lateCancellationPenalty,
              receiverId: carlaId,
              receiverName: 'Carlinha',
            ),
          ],
          passages: const [],
        ),
      );
      await h.pumpApp(tester, location: '/games', textScale: 1.5);
      await h.push(tester, '/games/$finishedId');
      expect(tester.takeException(), isNull);
      await h.push(tester, '/games/$finishedId/split');
      expect(tester.takeException(), isNull);
    });
  });

  group('S76: TalkBack', () {
    testWidgets('card Rateio e linhas de valor tocáveis com rótulo e 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(),
          charges: [charge(brunoId, 'Brunão')],
          passages: const [],
        ),
      );
      await openDetail(tester, finishedId);

      final card = find.ancestor(
        of: find.text(l10nPt.splitCardTitle),
        matching: find.byType(InkWell),
      );
      expect(card, findsOneWidget);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await h.push(tester, '/games/$finishedId/split');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}

const _others = [
  (daviId, 'Davi'),
  ('00000000-0000-0000-0000-0000000000a2', 'Gabi'),
  ('00000000-0000-0000-0000-0000000000a3', 'Hugo'),
  ('00000000-0000-0000-0000-0000000000a4', 'Iara'),
  ('00000000-0000-0000-0000-0000000000a5', 'João'),
  ('00000000-0000-0000-0000-0000000000a6', 'Kátia'),
  ('00000000-0000-0000-0000-0000000000a7', 'Lara'),
  ('00000000-0000-0000-0000-0000000000a8', 'Marcos'),
];
