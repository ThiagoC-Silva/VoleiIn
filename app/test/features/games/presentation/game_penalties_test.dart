import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/features/games/domain/game_models.dart';
import 'package:voleiin/features/games/presentation/game_badges.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S67, S69 (Isentos), S70, S71, S75 e S76 da etapa B de
/// docs/testes-referencia.md, seção 13 (docs/ui/telas.md, 8.1 a 8.3;
/// gameComplete.png, gameSplit-isentar.png e game-concluido.png): faltas na
/// conclusão, isenção manual no Rateio e o card "Sua participação".
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

  Future<void> tapFinder(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Finder absentBox(String userId) => find.descendant(
    of: find.byKey(Key('absent-$userId')),
    matching: find.byType(Checkbox),
  );

  bool? isChecked(WidgetTester tester, String userId) =>
      tester.widget<Checkbox>(absentBox(userId)).value;

  /// Edu saiu às 20:30 (domingo, 15/11, em Fortaleza), depois do início.
  final eduLeftAt = DateTime.utc(2026, 11, 15, 23, 30);

  /// Ana (recebedora), Brunão, Edu `left_after_start` com falta e Carlinha.
  List<GameParticipant> s67Participants() => [
    participant(anaId, 'Ana'),
    participant(brunoId, 'Brunão', minute: 1),
    participant(
      eduId,
      'Edu',
      minute: 2,
      status: ParticipantStatus.leftAfterStart,
    ).copyWith(absent: true, leftAt: eduLeftAt),
    participant(carlaId, 'Carlinha', minute: 3),
  ];

  const s67Preview = CompletionPreview(
    shareCents: 2084,
    totalToReceiveCents: 6252,
    receiverCoveredCents: 18748,
    uncoveredSlots: 8,
    penaltiesExempted: 2,
  );

  Future<void> openComplete(WidgetTester tester, {double textScale = 1}) async {
    await h.pumpApp(tester, location: '/games', textScale: textScale);
    await h.push(tester, '/games/$finishedId');
    await h.push(tester, '/games/$finishedId/complete');
  }

  group('S67: faltas na conclusão', () {
    testWidgets('Edu já marcado, sem a Ana, com completeReceiverNoAbsence', (
      tester,
    ) async {
      h.game(() => finishedGame(participants: s67Participants()));
      stubPreview(() async => s67Preview);
      await openComplete(tester);

      expect(find.text(l10nPt.completeAbsentTitle), findsOneWidget);
      expect(isChecked(tester, eduId), isTrue);
      expect(find.text(l10nPt.completeLeftAt('20:30')), findsOneWidget);
      expect(isChecked(tester, brunoId), isFalse);
      expect(isChecked(tester, carlaId), isFalse);
      expect(find.byKey(const Key('absent-$anaId')), findsNothing);
      expect(find.text('Ana'), findsNothing);
      expect(find.text(l10nPt.completeReceiverNoAbsence), findsOneWidget);
      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [eduId],
        ),
      ).called(1);
      expect(
        find.text('2 multas de cancelamento isentadas: sobraram vagas.'),
        findsOneWidget,
      );
    });

    testWidgets('marcar Carla e desmarcar Edu refazem o preview', (
      tester,
    ) async {
      h.game(() => finishedGame(participants: s67Participants()));
      stubPreview(() async => s67Preview);
      await openComplete(tester);

      await tapFinder(tester, absentBox(carlaId));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(isChecked(tester, carlaId), isTrue);
      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [eduId, carlaId],
        ),
      ).called(1);

      await tapFinder(tester, absentBox(eduId));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(isChecked(tester, eduId), isFalse);
      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [carlaId],
        ),
      ).called(1);
      expect(isEnabled<FilledButton>(tester, l10nPt.gameComplete), isTrue);
    });

    testWidgets('complete_game com as faltas do último preview', (
      tester,
    ) async {
      h.game(() => finishedGame(participants: s67Participants()));
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => GameSplit(
          game: completedGame(),
          charges: const [],
          passages: const [],
        ),
      );
      stubPreview(() async => s67Preview);
      when(
        () => h.games.completeGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      ).thenAnswer((_) async => s67Preview);
      await openComplete(tester);
      await tapFinder(tester, absentBox(carlaId));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.gameComplete),
      );
      await tapText(tester, l10nPt.completeConfirmAction);

      verify(
        () => h.games.completeGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [eduId, carlaId],
        ),
      ).called(1);
    });

    testWidgets('ABSENT_NOT_PARTICIPANT: SnackBar, relê e refaz o preview', (
      tester,
    ) async {
      var participants = s67Participants();
      h.game(() => finishedGame(participants: participants));
      stubPreview(() async => s67Preview);
      when(
        () => h.games.completeGame(
          gameId: any(named: 'gameId'),
          totalCents: any(named: 'totalCents'),
          absentUserIds: any(named: 'absentUserIds'),
        ),
      ).thenAnswer(
        (_) async => throw const AppException(ErrorCode.absentNotParticipant),
      );
      await openComplete(tester);
      await tapFinder(tester, absentBox(carlaId));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      clearInteractions(h.games);

      // Carla saiu da lista enquanto a tela estava aberta.
      participants = [
        for (final p in participants)
          if (p.userId != carlaId) p,
      ];
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.gameComplete),
      );
      await tapText(tester, l10nPt.completeConfirmAction);

      expect(find.text(l10nPt.errorAbsentNotParticipant), findsOneWidget);
      expect(h.location, '/games/$finishedId/complete');
      verify(() => h.games.fetchGame(finishedId)).called(greaterThan(0));
      expect(find.byKey(const Key('absent-$carlaId')), findsNothing);
      verify(
        () => h.games.previewCompleteGame(
          gameId: finishedId,
          totalCents: null,
          absentUserIds: const [eduId],
        ),
      ).called(greaterThan(0));
    });
  });

  /// O R08: dez valores Pendentes de R$ 20,84 e a multa da Carla isentada
  /// pelo admin; Fábio isento na conclusão.
  GameSplit r08Split({GameDetail? game}) => GameSplit(
    game: game ?? completedGame(),
    charges: [
      charge(brunoId, 'Brunão'),
      charge(eduId, 'Edu', kind: ChargeKind.absencePenalty),
      for (final (id, name) in _others) charge(id, name),
      charge(
        carlaId,
        'Carlinha',
        kind: ChargeKind.lateCancellationPenalty,
        status: ChargeStatus.waived,
        waiveReason: ChargeWaiveReason.manualWaiver,
      ),
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

  testWidgets('S69 (Isentos): a multa isentada pelo admin, no fim', (
    tester,
  ) async {
    h.game(() => completedGame());
    when(() => h.games.fetchSplit(finishedId))
        .thenAnswer((_) async => r08Split());
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$finishedId/split');

    expect(find.text(formatCents(20840)), findsOneWidget);
    expect(find.text(formatCents(4160)), findsWidgets);
    expect(find.text(l10nPt.splitWaived), findsOneWidget);
    expect(find.text(l10nPt.chargeWaivedManual), findsOneWidget);
    final badges = tester
        .widgetList<ChargeStatusBadge>(find.byType(ChargeStatusBadge))
        .map((b) => b.status)
        .toList();
    expect(badges.where((s) => s == ChargeStatus.pending), hasLength(10));
    expect(badges.where((s) => s == ChargeStatus.waived), hasLength(1));
    // A seção Isentos vem depois de Valores.
    expect(
      tester.getTopLeft(find.text(l10nPt.splitWaived)).dy,
      greaterThan(tester.getTopLeft(find.text(l10nPt.splitCharges)).dy),
    );
  });

  group('S70: isentar multa', () {
    void stubWaive(Future<void> Function() answer) {
      when(() => h.games.waivePenalty(any())).thenAnswer((_) => answer());
    }

    testWidgets('Ana isenta a multa Pendente do Edu', (tester) async {
      var waived = false;
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId)).thenAnswer(
        (_) async => waived
            ? GameSplit(
                game: completedGame(),
                charges: [
                  charge(
                    eduId,
                    'Edu',
                    kind: ChargeKind.absencePenalty,
                    status: ChargeStatus.waived,
                    waiveReason: ChargeWaiveReason.manualWaiver,
                  ),
                ],
                passages: const [],
              )
            : r08Split(),
      );
      stubWaive(() async => waived = true);
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      await tapText(tester, 'Edu');
      expect(find.text(l10nPt.waiveAction), findsOneWidget);
      expect(find.text(l10nPt.waiveActionHint), findsOneWidget);
      expect(h.location, '/games/$finishedId/split');

      await tapText(tester, l10nPt.waiveAction);
      expect(find.text(l10nPt.waiveTitle('Edu')), findsOneWidget);
      expect(find.text(l10nPt.waiveBody), findsOneWidget);
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.waiveAction).last,
      );

      verify(() => h.games.waivePenalty('charge-$eduId')).called(1);
      expect(find.text(l10nPt.penaltyWaived), findsOneWidget);
      // A tela relê: a linha do Edu foi para Isentos.
      expect(find.text(l10nPt.splitWaived), findsOneWidget);
      expect(find.text(l10nPt.chargeWaivedManual), findsOneWidget);
    });

    testWidgets('Voltar na confirmação não isenta', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      stubWaive(() async {});
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      await tapText(tester, 'Edu');
      await tapText(tester, l10nPt.waiveAction);
      await tapText(tester, l10nPt.commonBack);

      verifyNever(() => h.games.waivePenalty(any()));
    });

    testWidgets('Ana toca num share: o perfil, sem sheet', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      await tapText(tester, 'Brunão');

      expect(find.text(l10nPt.waiveAction), findsNothing);
      expect(h.location, '/games/$finishedId/people/$brunoId');
    });

    testWidgets('Bruno, recebedor sem ser admin, toca na multa: o perfil', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      final game = completedGame(viewerId: brunoId)
          .copyWith(receiverId: brunoId, receiverName: 'Brunão');
      h.game(() => game);
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split(game: game));
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      await tapText(tester, 'Edu');

      expect(find.text(l10nPt.waiveAction), findsNothing);
      expect(h.location, '/games/$finishedId/people/$eduId');
    });

    testWidgets('Ana toca na multa já Isenta: o perfil', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');

      await tapText(tester, 'Carlinha');

      expect(find.text(l10nPt.waiveAction), findsNothing);
      expect(h.location, '/games/$finishedId/people/$carlaId');
    });

    testWidgets('CHARGE_NOT_PENDING: SnackBar, e a tela relê', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      stubWaive(
        () async => throw const AppException(ErrorCode.chargeNotPending),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');
      clearInteractions(h.games);

      await tapText(tester, 'Edu');
      await tapText(tester, l10nPt.waiveAction);
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.waiveAction).last,
      );

      expect(find.text(l10nPt.errorChargeNotPending), findsOneWidget);
      verify(() => h.games.fetchSplit(finishedId)).called(1);
    });
  });

  group('S71: Sua participação', () {
    /// Bruno cancelou às 18:30, fora do prazo (18:00), voltou às 19:00 e foi
    /// marcado faltoso na conclusão.
    List<GamePassage> brunoPassages() => [
      GamePassage(
        userId: brunoId,
        displayName: 'Brunão',
        status: ParticipantStatus.cancelled,
        joinedAt: DateTime.utc(2026, 11, 14, 13),
        leftAt: DateTime.utc(2026, 11, 15, 21, 30),
        lateCancellation: true,
        cancellationVoidedAt: DateTime.utc(2026, 11, 15, 22),
      ),
      GamePassage(
        userId: brunoId,
        displayName: 'Brunão',
        status: ParticipantStatus.active,
        joinedAt: DateTime.utc(2026, 11, 15, 22),
        absent: true,
        absenceSource: AbsenceSource.markedByAdmin,
      ),
    ];

    Finder inCard(Finder finder) => find.descendant(
      of: find.byKey(const Key('historyCard')),
      matching: finder,
    );

    testWidgets('Bruno: cancelou fora do prazo, voltou e faltou', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      h.game(
        () => completedGame(
          viewerId: brunoId,
          myCharge: charge(brunoId, 'Brunão', kind: ChargeKind.absencePenalty),
        ).copyWith(myPassages: brunoPassages()),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId');

      expect(inCard(find.text(l10nPt.historyTitle)), findsOneWidget);
      expect(
        inCard(find.text(l10nPt.historyCancelledLate('dom, 15/11', '18:30'))),
        findsOneWidget,
      );
      expect(inCard(find.text(l10nPt.historyVoided('19:00'))), findsOneWidget);
      expect(inCard(find.text(l10nPt.historyMarkedAbsent)), findsOneWidget);
      expect(inCard(find.text(l10nPt.chargeKindAbsence)), findsOneWidget);
      expect(inCard(find.text(formatCents(2084))), findsOneWidget);
      expect(inCard(find.byType(ChargeStatusBadge)), findsOneWidget);
      // Antes do card Rateio (game-concluido.png).
      expect(
        tester.getTopLeft(find.byKey(const Key('historyCard'))).dy,
        lessThan(tester.getTopLeft(find.text(l10nPt.splitCardTitle)).dy),
      );
    });

    testWidgets('Carla, só na lista e com a parte: sem card', (tester) async {
      h.signedIn(userId: carlaId);
      h.game(
        () =>
            completedGame(
              viewerId: carlaId,
              myCharge: charge(carlaId, 'Carlinha'),
            ).copyWith(
              myPassages: [
                GamePassage(
                  userId: carlaId,
                  displayName: 'Carlinha',
                  status: ParticipantStatus.active,
                  joinedAt: DateTime.utc(2026, 11, 14, 13),
                ),
              ],
            ),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId');

      expect(find.byKey(const Key('historyCard')), findsNothing);
      expect(find.text(l10nPt.historyTitle), findsNothing);
    });

    testWidgets('Davi, que cancelou no prazo: historyCancelledOnTime e '
        'splitNoCharge', (tester) async {
      h.signedIn(userId: daviId);
      h.game(
        () => completedGame(viewerId: daviId).copyWith(
          myPassages: [
            GamePassage(
              userId: daviId,
              displayName: 'Davi',
              status: ParticipantStatus.cancelled,
              joinedAt: DateTime.utc(2026, 11, 14, 13),
              leftAt: DateTime.utc(2026, 11, 15, 20),
            ),
          ],
        ),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId');

      expect(
        inCard(find.text(l10nPt.historyCancelledOnTime('dom, 15/11', '17:00'))),
        findsOneWidget,
      );
      expect(inCard(find.text(l10nPt.splitNoCharge)), findsOneWidget);
    });

    testWidgets('as outras linhas: isenção, saída depois do início e '
        'remoções', (tester) async {
      h.signedIn(userId: fabioId);
      h.game(
        () => finishedGame(viewerId: fabioId).copyWith(
          myPassages: [
            GamePassage(
              userId: fabioId,
              displayName: 'Fábio',
              status: ParticipantStatus.cancelled,
              joinedAt: DateTime.utc(2026, 11, 14, 13),
              leftAt: DateTime.utc(2026, 11, 15, 21, 30),
              lateCancellation: true,
              lateCancellationExempt: true,
            ),
            GamePassage(
              userId: fabioId,
              displayName: 'Fábio',
              status: ParticipantStatus.removed,
              joinedAt: DateTime.utc(2026, 11, 15, 12),
              leftAt: DateTime.utc(2026, 11, 15, 13),
              removalReason: RemovalReason.byAdmin,
            ),
            GamePassage(
              userId: fabioId,
              displayName: 'Fábio',
              status: ParticipantStatus.removed,
              joinedAt: DateTime.utc(2026, 11, 15, 14),
              leftAt: DateTime.utc(2026, 11, 15, 15),
              removalReason: RemovalReason.leftGroup,
            ),
            GamePassage(
              userId: fabioId,
              displayName: 'Fábio',
              status: ParticipantStatus.leftAfterStart,
              joinedAt: DateTime.utc(2026, 11, 15, 16),
              leftAt: eduLeftAt,
              absent: true,
              absenceSource: AbsenceSource.leftAfterStart,
            ),
          ],
        ),
      );
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId');

      expect(
        inCard(find.text(l10nPt.historyCancelledLate('dom, 15/11', '18:30'))),
        findsOneWidget,
      );
      expect(inCard(find.text(l10nPt.historyExempt)), findsOneWidget);
      expect(
        inCard(find.text(l10nPt.historyRemovedByAdmin('dom, 15/11'))),
        findsOneWidget,
      );
      expect(
        inCard(find.text(l10nPt.historyRemovedGroupLeft('dom, 15/11'))),
        findsOneWidget,
      );
      expect(
        inCard(find.text(l10nPt.historyLeftAfterStart('20:30'))),
        findsOneWidget,
      );
      expect(inCard(find.text(l10nPt.historyAbsentLeft)), findsOneWidget);
      // Antes da conclusão, sem a linha de valor.
      expect(inCard(find.text(l10nPt.splitNoCharge)), findsNothing);
    });
  });

  group('S75: fonte em 150%', () {
    testWidgets('conclusão com as faltas, sem overflow', (tester) async {
      h.game(() => finishedGame(participants: s67Participants()));
      stubPreview(() async => s67Preview);
      await openComplete(tester, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sheet e confirmação da isenção, sem overflow', (tester) async {
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      await h.pumpApp(tester, location: '/games', textScale: 1.5);
      await h.push(tester, '/games/$finishedId/split');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Edu');
      expect(tester.takeException(), isNull);
      await tapText(tester, l10nPt.waiveAction);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detalhe com Sua participação, sem overflow', (tester) async {
      h.signedIn(userId: brunoId);
      h.game(
        () =>
            completedGame(
              viewerId: brunoId,
              myCharge: charge(
                brunoId,
                'Brunão',
                kind: ChargeKind.lateCancellationPenalty,
              ),
            ).copyWith(
              myPassages: [
                GamePassage(
                  userId: brunoId,
                  displayName: 'Brunão',
                  status: ParticipantStatus.cancelled,
                  joinedAt: DateTime.utc(2026, 11, 14, 13),
                  leftAt: DateTime.utc(2026, 11, 15, 21, 30),
                  lateCancellation: true,
                  cancellationVoidedAt: DateTime.utc(2026, 11, 15, 22),
                ),
              ],
            ),
      );
      await h.pumpApp(tester, location: '/games', textScale: 1.5);
      await h.push(tester, '/games/$finishedId');
      expect(tester.takeException(), isNull);
    });
  });

  group('S76: TalkBack', () {
    testWidgets('caixas de falta com completeAbsentLabel e 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      h.game(() => finishedGame(participants: s67Participants()));
      stubPreview(() async => s67Preview);
      await openComplete(tester);

      for (final name in ['Brunão', 'Edu', 'Carlinha']) {
        expect(
          find.bySemanticsLabel(l10nPt.completeAbsentLabel(name)),
          findsOneWidget,
        );
      }
      expect(
        tester.getSize(find.byKey(const Key('absent-$carlaId'))).height,
        greaterThanOrEqualTo(48),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('sheet da isenção com rótulo e 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      h.game(() => completedGame());
      when(() => h.games.fetchSplit(finishedId))
          .thenAnswer((_) async => r08Split());
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/$finishedId/split');
      await tapText(tester, 'Edu');

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
