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

/// Cenários S84 (sem **Conferir comprovante**), S88 e S89 da etapa A de
/// docs/testes-referencia.md, seção 14 (docs/ui/telas.md, 9.2 e 9.5;
/// gameSplit-marcarPago.png): as ações do recebedor no Rateio e o **Pagar**
/// de quem deve.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  Future<void> tapFinder(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  /// Os valores do S84, devidos à Ana.
  List<GameCharge> s84Charges() => [
    charge(fabioId, 'Fábio'),
    charge(carlaId, 'Carlinha', kind: ChargeKind.lateCancellationPenalty),
    charge(
      daviId,
      'Davi',
      status: ChargeStatus.paid,
      paidVia: PaymentMethod.manual,
    ),
    charge(
      diegoId,
      'Diego',
      status: ChargeStatus.paid,
      paidVia: PaymentMethod.receipt,
    ),
    charge(brunoId, 'Brunão', status: ChargeStatus.underReview),
  ];

  /// Abre o Rateio. Cada leitura chama [charges] de novo.
  Future<void> openSplit(
    WidgetTester tester, {
    GameDetail? game,
    List<GameCharge> Function()? charges,
    double textScale = 1,
  }) async {
    final detail = game ?? completedGame();
    h.game(() => detail);
    when(() => h.games.fetchSplit(finishedId)).thenAnswer(
      (_) async => GameSplit(
        game: detail,
        charges: (charges ?? s84Charges)(),
        passages: const [],
      ),
    );
    await h.pumpApp(tester, location: '/games', textScale: textScale);
    await h.push(tester, '/games/$finishedId/split');
  }

  group('S84: as opções de cada valor', () {
    testWidgets('Ana, no valor Pendente do Fábio: Marcar como pago', (
      tester,
    ) async {
      await openSplit(tester);
      await tapText(tester, 'Fábio');

      expect(
        inSheet(
          '${l10nPt.chargeKindShare} · ${formatCents(2084)} · '
          '${l10nPt.chargeStatusPending}',
        ),
        findsOneWidget,
      );
      expect(inSheet(l10nPt.markPaidAction), findsOneWidget);
      expect(inSheet(l10nPt.markPaidHint), findsOneWidget);
      expect(inSheet(l10nPt.groupMemberViewProfile), findsOneWidget);
      expect(inSheet(l10nPt.waiveAction), findsNothing);
      expect(inSheet(l10nPt.revertAction), findsNothing);
    });

    testWidgets('Ana, na multa Pendente da Carla: Marcar como pago e Isentar '
        'multa', (tester) async {
      await openSplit(tester);
      await tapText(tester, 'Carlinha');

      expect(inSheet(l10nPt.markPaidAction), findsOneWidget);
      expect(inSheet(l10nPt.waiveAction), findsOneWidget);
      expect(inSheet(l10nPt.groupMemberViewProfile), findsOneWidget);
    });

    testWidgets('Ana, no Pago manual: só Reverter pagamento', (tester) async {
      await openSplit(tester);
      await tapText(tester, 'Davi');

      expect(inSheet(l10nPt.revertAction), findsOneWidget);
      expect(inSheet(l10nPt.revertHint), findsOneWidget);
      expect(inSheet(l10nPt.markPaidAction), findsNothing);
    });

    testWidgets('Ana, no Pago por comprovante: o perfil, sem sheet', (
      tester,
    ) async {
      await openSplit(tester);
      await tapText(tester, 'Diego');

      expect(find.byType(BottomSheet), findsNothing);
      expect(h.location, '/games/$finishedId/people/$diegoId');
    });

    testWidgets('Edu, admin, na multa: só Isentar multa', (tester) async {
      h.signedIn(userId: eduId);
      await openSplit(
        tester,
        game: completedGame(viewerId: eduId).copyWith(adminIds: [anaId, eduId]),
      );
      await tapText(tester, 'Carlinha');

      expect(inSheet(l10nPt.waiveAction), findsOneWidget);
      expect(inSheet(l10nPt.markPaidAction), findsNothing);
      expect(inSheet(l10nPt.groupMemberViewProfile), findsOneWidget);
    });

    testWidgets('Edu, admin, na parte do Fábio: o perfil, sem sheet', (
      tester,
    ) async {
      h.signedIn(userId: eduId);
      await openSplit(
        tester,
        game: completedGame(viewerId: eduId).copyWith(adminIds: [anaId, eduId]),
      );
      await tapText(tester, 'Fábio');

      expect(find.byType(BottomSheet), findsNothing);
      expect(h.location, '/games/$finishedId/people/$fabioId');
    });

    testWidgets('Ver perfil abre o perfil', (tester) async {
      await openSplit(tester);
      await tapText(tester, 'Fábio');
      await tapFinder(tester, inSheet(l10nPt.groupMemberViewProfile));

      expect(h.location, '/games/$finishedId/people/$fabioId');
    });

    testWidgets('Bruno, antigo recebedor sem ser admin: Devidos a você', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      await openSplit(
        tester,
        game: completedGame(viewerId: brunoId),
        charges: () => [
          charge(brunoId, 'Brunão'),
          charge(
            daviId,
            'Davi',
            status: ChargeStatus.paid,
            paidVia: PaymentMethod.manual,
            receiverId: brunoId,
            receiverName: 'Brunão',
          ),
        ],
      );

      expect(find.text(l10nPt.splitOwedToYou), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l10nPt.splitOwedToYou)).dy,
        greaterThan(tester.getTopLeft(find.text(l10nPt.splitYourValue)).dy),
      );
      // Só a linha devida a ele, sem os totais do recebedor (RN76).
      expect(find.text(l10nPt.splitCharges), findsNothing);
      expect(find.text(l10nPt.splitReceived), findsNothing);

      await tapText(tester, 'Davi');
      expect(inSheet(l10nPt.revertAction), findsOneWidget);
    });

    testWidgets('sem ser antigo recebedor, ou sendo recebedora ou admin: sem '
        'Devidos a você', (tester) async {
      await openSplit(tester);
      expect(find.text(l10nPt.splitOwedToYou), findsNothing);
    });
  });

  group('S84: marcar como pago', () {
    testWidgets('confirma, chama mark_charge_paid, SnackBar e relê', (
      tester,
    ) async {
      var paid = false;
      when(() => h.games.markChargePaid(any())).thenAnswer((_) async {
        paid = true;
      });
      await openSplit(
        tester,
        charges: () => [
          charge(
            fabioId,
            'Fábio',
            status: paid ? ChargeStatus.paid : ChargeStatus.pending,
            paidVia: paid ? PaymentMethod.manual : null,
          ),
        ],
      );
      clearInteractions(h.games);

      await tapText(tester, 'Fábio');
      await tapText(tester, l10nPt.markPaidAction);
      expect(
        find.text(l10nPt.markPaidTitle('Fábio', formatCents(2084))),
        findsOneWidget,
      );
      expect(find.text(l10nPt.markPaidBody), findsOneWidget);
      verifyNever(() => h.games.markChargePaid(any()));
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.markPaidAction),
      );

      verify(() => h.games.markChargePaid('charge-$fabioId')).called(1);
      expect(find.text(l10nPt.markedPaid), findsOneWidget);
      verify(() => h.games.fetchSplit(finishedId)).called(1);
      verify(() => h.games.fetchMyCharges()).called(greaterThan(0));
      // Recebido: R$ 20,84; a linha ficou Paga.
      expect(
        find.descendant(
          of: find.byKey(const Key('splitReceivedTotal')),
          matching: find.text(formatCents(2084)),
        ),
        findsOneWidget,
      );
      expect(find.text(l10nPt.chargeStatusPaid), findsOneWidget);
    });

    testWidgets('Voltar na confirmação não marca', (tester) async {
      await openSplit(tester);
      await tapText(tester, 'Fábio');
      await tapText(tester, l10nPt.markPaidAction);
      await tapText(tester, l10nPt.commonBack);

      verifyNever(() => h.games.markChargePaid(any()));
    });

    testWidgets('CHARGE_NOT_PENDING: SnackBar, e a tela relê', (tester) async {
      when(() => h.games.markChargePaid(any())).thenAnswer(
        (_) async => throw const AppException(ErrorCode.chargeNotPending),
      );
      await openSplit(tester);
      clearInteractions(h.games);

      await tapText(tester, 'Fábio');
      await tapText(tester, l10nPt.markPaidAction);
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.markPaidAction),
      );

      expect(find.text(l10nPt.errorChargeNotPending), findsOneWidget);
      verify(() => h.games.fetchSplit(finishedId)).called(1);
    });
  });

  group('S84: reverter pagamento', () {
    testWidgets('confirma, chama revert_charge, SnackBar e relê', (
      tester,
    ) async {
      when(() => h.games.revertCharge(any())).thenAnswer((_) async {});
      await openSplit(tester);
      clearInteractions(h.games);

      await tapText(tester, 'Davi');
      await tapText(tester, l10nPt.revertAction);
      expect(find.text(l10nPt.revertTitle('Davi')), findsOneWidget);
      expect(find.text(l10nPt.revertBody('Davi')), findsOneWidget);
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.revertAction),
      );

      verify(() => h.games.revertCharge('charge-$daviId')).called(1);
      expect(find.text(l10nPt.paymentReverted), findsOneWidget);
      verify(() => h.games.fetchSplit(finishedId)).called(1);
    });

    testWidgets('CHARGE_NOT_REVERTIBLE: SnackBar, e a tela relê', (
      tester,
    ) async {
      when(() => h.games.revertCharge(any())).thenAnswer(
        (_) async => throw const AppException(ErrorCode.chargeNotRevertible),
      );
      await openSplit(tester);
      clearInteractions(h.games);

      await tapText(tester, 'Davi');
      await tapText(tester, l10nPt.revertAction);
      await tapFinder(
        tester,
        buttonWithText<FilledButton>(l10nPt.revertAction),
      );

      expect(find.text(l10nPt.errorChargeNotRevertible), findsOneWidget);
      verify(() => h.games.fetchSplit(finishedId)).called(1);
    });
  });

  group('Seu valor (telas.md, 9.2)', () {
    void signInFabio({ChargeStatus status = ChargeStatus.pending}) {
      h.signedIn(userId: fabioId);
      when(
        () => h.games.fetchCharge('charge-$fabioId'),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
    }

    testWidgets('Pendente: Pagar abre o valor a pagar, em Cobranças', (
      tester,
    ) async {
      signInFabio();
      await openSplit(
        tester,
        game: completedGame(viewerId: fabioId),
        charges: () => [charge(fabioId, 'Fábio')],
      );

      await tapFinder(tester, buttonWithText<OutlinedButton>(l10nPt.chargePay));
      expect(h.location, '/charges/charge-$fabioId');
    });

    testWidgets('Pago: sem Pagar, e tocar no bloco abre o valor a pagar', (
      tester,
    ) async {
      signInFabio();
      await openSplit(
        tester,
        game: completedGame(viewerId: fabioId),
        charges: () => [
          charge(
            fabioId,
            'Fábio',
            status: ChargeStatus.paid,
            paidVia: PaymentMethod.manual,
          ),
        ],
      );

      expect(find.text(l10nPt.chargePay), findsNothing);
      await tapText(tester, l10nPt.splitOwedTo('Ana'));
      expect(h.location, '/charges/charge-$fabioId');
    });
  });

  group('S88: fonte em 150%', () {
    testWidgets('sheet com as opções e as confirmações, sem overflow', (
      tester,
    ) async {
      await openSplit(tester, textScale: 1.5);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Carlinha');
      expect(tester.takeException(), isNull);
      await tapText(tester, l10nPt.markPaidAction);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Seu valor com Pagar e Devidos a você, sem overflow', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      await openSplit(
        tester,
        textScale: 1.5,
        game: completedGame(viewerId: brunoId),
        charges: () => [
          charge(brunoId, 'Brunão'),
          charge(daviId, 'Davi', receiverId: brunoId, receiverName: 'Brunão'),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('S89: TalkBack', () {
    testWidgets('a sheet do recebedor e o bloco Seu valor com rótulo e 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      h.signedIn(userId: brunoId);
      await openSplit(
        tester,
        game: completedGame(viewerId: brunoId),
        charges: () => [
          charge(brunoId, 'Brunão'),
          charge(daviId, 'Davi', receiverId: brunoId, receiverName: 'Brunão'),
        ],
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tapText(tester, 'Davi');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
