import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/shared/widgets/bottom_nav.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S74, S75 e S76 da etapa C de docs/testes-referencia.md, seção 13
/// (docs/ui/telas.md, 8.5; charges.png e charges-vazio.png): a aba Cobranças,
/// com os totais a pagar e a receber e o contador da aba.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  /// Quinta, 19/11/2026, 20:00 em Fortaleza.
  final thursday = DateTime.utc(2026, 11, 19, 23);

  /// Sábado, 21/11/2026, 20:00 em Fortaleza.
  final saturday = DateTime.utc(2026, 11, 21, 23);

  const thursdayGame = '00000000-0000-0000-0000-000000000301';
  const saturdayGame = '00000000-0000-0000-0000-000000000302';

  ChargeLine line({
    required String id,
    required String gameId,
    required DateTime startsAt,
    required String location,
    required String payerId,
    required String receiverId,
    required String receiverName,
    ChargeKind kind = ChargeKind.share,
    int amountCents = 2084,
    ChargeStatus status = ChargeStatus.pending,
  }) => ChargeLine(
    id: id,
    gameId: gameId,
    startsAt: startsAt,
    locationName: location,
    payerId: payerId,
    receiverId: receiverId,
    receiverName: receiverName,
    kind: kind,
    amountCents: amountCents,
    status: status,
  );

  /// Bruno deve a parte de R$ 20,84 à Ana na quinta e a multa por falta de
  /// R$ 15,00 à Carlinha no sábado. A lista vem fora de ordem do servidor.
  List<ChargeLine> brunoLines() => [
    line(
      id: 'c2',
      gameId: saturdayGame,
      startsAt: saturday,
      location: 'Ginásio Verdão',
      payerId: brunoId,
      receiverId: carlaId,
      receiverName: 'Carlinha',
      kind: ChargeKind.absencePenalty,
      amountCents: 1500,
    ),
    line(
      id: 'c1',
      gameId: thursdayGame,
      startsAt: thursday,
      location: 'Quadra do Sesc',
      payerId: brunoId,
      receiverId: anaId,
      receiverName: 'Ana',
    ),
  ];

  /// Ana recebe 11 valores Pendentes de R$ 20,84 no jogo de quinta.
  List<ChargeLine> anaLines() => [
    for (var i = 0; i < 11; i++)
      line(
        id: 'r$i',
        gameId: thursdayGame,
        startsAt: thursday,
        location: 'Quadra do Sesc',
        payerId: 'payer-$i',
        receiverId: anaId,
        receiverName: 'Ana',
      ),
  ];

  Finder tabBadge() => find.descendant(
    of: find.byType(VoleiBottomNav),
    matching: find.byType(Badge),
  );

  Future<void> openCharges(WidgetTester tester, {double textScale = 1}) =>
      h.pumpApp(tester, location: '/charges', textScale: textScale);

  void signInBruno() {
    h.signedIn(userId: brunoId);
    h.myCharges(brunoLines(), viewerId: brunoId);
  }

  group('S74: Cobranças', () {
    testWidgets('Bruno: A pagar R\$ 35,84 em 2 jogos, as linhas na ordem', (
      tester,
    ) async {
      signInBruno();
      await openCharges(tester);

      expect(find.text(l10nPt.chargesTitle), findsWidgets);
      expect(find.text(formatCents(3584)), findsOneWidget);
      expect(find.text('em 2 jogos'), findsOneWidget);

      final first = find.text('qui, 19/11 · Quadra do Sesc');
      final second = find.text('sáb, 21/11 · Ginásio Verdão');
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(find.text('Para Ana'), findsOneWidget);
      expect(find.text('Para Carlinha · Multa por falta'), findsOneWidget);
      expect(find.text(formatCents(2084)), findsOneWidget);
      expect(find.text(formatCents(1500)), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10nPt.chargesNothingToReceive),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10nPt.chargesNothingToReceive), findsOneWidget);

      // O contador da aba: os 2 valores Pendentes.
      expect(
        find.descendant(of: tabBadge(), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('Ana: A receber R\$ 229,24 de 11 pessoas, uma linha', (
      tester,
    ) async {
      h.myCharges(anaLines());
      await openCharges(tester);

      expect(find.text(formatCents(22924)), findsNWidgets(2));
      expect(find.text('de 11 pessoas'), findsOneWidget);
      expect(find.text('qui, 19/11 · Quadra do Sesc'), findsOneWidget);
      expect(find.text('11 pessoas'), findsOneWidget);
      expect(find.text(l10nPt.chargesNothingToPay), findsOneWidget);
      expect(tabBadge(), findsNothing);
    });

    testWidgets('A receber: tocar numa linha abre o Rateio do jogo, na aba '
        'Jogos', (tester) async {
      h.myCharges(anaLines());
      h.gameNotFound(thursdayGame);
      when(
        () => h.games.fetchSplit(thursdayGame),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await openCharges(tester);

      await tester.tap(find.text('qui, 19/11 · Quadra do Sesc'));
      await tester.pumpAndSettle();
      expect(h.location, '/games/$thursdayGame/split');
    });

    testWidgets('sem nenhum valor: chargesEmptyTitle, sem as seções', (
      tester,
    ) async {
      await openCharges(tester);

      expect(find.text(l10nPt.chargesEmptyTitle), findsOneWidget);
      expect(find.text(l10nPt.chargesEmptyBody), findsOneWidget);
      expect(find.text(l10nPt.chargesToPay), findsNothing);
      expect(find.text(l10nPt.chargesToReceive), findsNothing);
    });

    testWidgets('falha de carga: Tentar de novo relê', (tester) async {
      var calls = 0;
      when(() => h.games.fetchMyCharges()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw const AppException(ErrorCode.internalError);
        return ChargesOverview(viewerId: anaId, lines: anaLines());
      });
      await openCharges(tester);

      expect(find.text(l10nPt.commonTryAgain), findsOneWidget);
      await tester.tap(find.text(l10nPt.commonTryAgain));
      await tester.pumpAndSettle();
      expect(find.text('de 11 pessoas'), findsOneWidget);
    });

    testWidgets('a aba relê ao ser aberta', (tester) async {
      signInBruno();
      await h.pumpApp(tester, location: '/games');
      clearInteractions(h.games);

      await tester.tap(
        find.descendant(
          of: find.byType(VoleiBottomNav),
          matching: find.text(l10nPt.navCharges),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => h.games.fetchMyCharges()).called(greaterThanOrEqualTo(1));
    });
  });

  // Etapa A da fatia 6 (docs/testes-referencia.md, seção 14): sem **Para
  // conferir**, que chega na etapa B.
  group('S85: A pagar abre o valor a pagar', () {
    testWidgets('tocar na linha abre /charges/:chargeId', (tester) async {
      signInBruno();
      when(
        () => h.games.fetchCharge('c2'),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await openCharges(tester);

      await tester.tap(find.text('sáb, 21/11 · Ginásio Verdão'));
      await tester.pumpAndSettle();
      expect(h.location, '/charges/c2');
      verify(() => h.games.fetchCharge('c2')).called(1);
    });
  });

  group('S75: fonte em 150%', () {
    testWidgets('Cobranças do Bruno, sem overflow', (tester) async {
      signInBruno();
      await openCharges(tester, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cobranças da Ana e o estado vazio, sem overflow', (
      tester,
    ) async {
      h.myCharges(anaLines());
      await openCharges(tester, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });

  group('S76: TalkBack', () {
    testWidgets('contador da aba com chargesTabBadgeLabel', (tester) async {
      final semantics = tester.ensureSemantics();
      signInBruno();
      await openCharges(tester);

      expect(
        find.bySemanticsLabel(RegExp(l10nPt.chargesTabBadgeLabel(2))),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('linhas e atalhos com rótulo e 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      signInBruno();
      await openCharges(tester);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
