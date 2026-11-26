import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/core/theme/app_theme.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/features/games/presentation/game_badges.dart';
import 'package:voleiin/features/payments/domain/receipt_models.dart';
import 'package:voleiin/features/payments/presentation/receipt_text.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S77, S88 e S89 das etapas A e B de docs/testes-referencia.md,
/// seção 14 (docs/ui/telas.md, 9.2; charge.png, charge-analise.png e
/// charge-pago.png): o valor a pagar do Fábio à Ana, com os comprovantes.
void main() {
  late TestHarness h;

  const chargeId = '00000000-0000-0000-0000-000000000501';

  setUp(() {
    h = TestHarness();
    h.signedIn(userId: fabioId);
  });

  ChargeDetail detail({
    ChargeStatus status = ChargeStatus.pending,
    PaymentMethod? paidVia,
    ChargeWaiveReason? waiveReason,
    String? groupName = 'Vôlei de Quinta',
    ChargeKind kind = ChargeKind.share,
    List<ReceiptSummary> receipts = const [],
    int autoReadsUsed = 0,
  }) {
    // A chave só vem do servidor com o valor Pendente ou Em análise (RN102).
    final open =
        status == ChargeStatus.pending || status == ChargeStatus.underReview;
    return ChargeDetail(
      id: chargeId,
      gameId: finishedId,
      groupName: groupName,
      // Quinta, 19/11/2026, 20:00 em Fortaleza.
      startsAt: DateTime.utc(2026, 11, 19, 23),
      locationName: 'Quadra do Sesc',
      receiverId: anaId,
      receiverName: 'Ana',
      receiverPixKeyType: open ? PixKeyType.cpf : null,
      receiverPixKey: open ? '52998224725' : null,
      kind: kind,
      amountCents: 2084,
      status: status,
      waiveReason: waiveReason,
      // Sexta, 20/11/2026, 09:10 em Fortaleza.
      paidAt: paidVia == null ? null : DateTime.utc(2026, 11, 20, 12, 10),
      paidVia: paidVia,
      receipts: receipts,
      autoReadsUsed: autoReadsUsed,
    );
  }

  /// Os dois recusados do charge.png, como o servidor os devolve: do mais
  /// antigo para o mais novo.
  List<ReceiptSummary> rejectedPair() => [
    ReceiptSummary(
      id: 'receipt-dup',
      status: ReceiptStatus.rejected,
      // Quinta, 19/11/2026, 22:30 em Fortaleza.
      createdAt: DateTime.utc(2026, 11, 20, 1, 30),
      rejectionReason: ReceiptRejectionReason.duplicateTransaction,
    ),
    ReceiptSummary(
      id: 'receipt-note',
      status: ReceiptStatus.rejected,
      // Sexta, 20/11/2026, 09:10 em Fortaleza.
      createdAt: DateTime.utc(2026, 11, 20, 12, 10),
      rejectionReason: ReceiptRejectionReason.receiverRejected,
      receiverNote: 'O valor está errado, faltam 4 centavos.',
    ),
  ];

  void stub(ChargeDetail value) {
    when(() => h.games.fetchCharge(chargeId)).thenAnswer((_) async => value);
  }

  Future<void> open(WidgetTester tester, {double textScale = 1}) =>
      h.pumpApp(tester, location: '/charges/$chargeId', textScale: textScale);

  Color heroColor(WidgetTester tester) {
    final hero = tester.widget<Container>(find.byKey(const Key('chargeHero')));
    return (hero.decoration! as BoxDecoration).color!;
  }

  ChargeStatus badge(WidgetTester tester) =>
      tester.widget<ChargeStatusBadge>(find.byType(ChargeStatusBadge)).status;

  group('S77: Valor a pagar', () {
    testWidgets('Pendente: o topo, Pagar para a Ana e a chave', (tester) async {
      stub(detail());
      await open(tester);

      expect(find.text('Vôlei de Quinta'), findsOneWidget);
      expect(find.text('qui, 19/11 · Quadra do Sesc'), findsOneWidget);
      expect(find.text(formatCents(2084)), findsOneWidget);
      expect(find.text(l10nPt.chargeKindShare), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      expect(badge(tester), ChargeStatus.pending);
      expect(heroColor(tester), VoleiColors.dark.owe);

      expect(find.text('Pagar para'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('CPF · 529.982.247-25'), findsOneWidget);
      expect(find.text(l10nPt.chargePayExact), findsOneWidget);
      expect(buttonWithText<FilledButton>(l10nPt.receiptSend), findsOneWidget);
      // Sem comprovante, sem a lista.
      expect(find.text(l10nPt.chargeReceipts), findsNothing);
    });

    testWidgets('com um recusado pela Ana e um por ID repetido: do mais novo '
        'para o mais antigo', (tester) async {
      stub(detail(receipts: rejectedPair()));
      await open(tester);

      final newer = find.text('Enviado sex, 20/11 às 09:10');
      final older = find.text('Enviado qui, 19/11 às 22:30');
      await tester.scrollUntilVisible(older, 200);
      expect(find.text(l10nPt.chargeReceipts), findsOneWidget);
      expect(newer, findsOneWidget);
      expect(
        tester.getTopLeft(newer).dy,
        lessThan(tester.getTopLeft(older).dy),
      );
      expect(find.text(l10nPt.receiptStatusRejected), findsNWidgets(2));
      expect(
        find.text(
          l10nPt.receiptNoteQuoted('O valor está errado, faltam 4 centavos.'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10nPt.receiptRejectedDuplicate), findsOneWidget);
      // Ainda Pendente: pode enviar outro.
      expect(buttonWithText<FilledButton>(l10nPt.receiptSend), findsOneWidget);
    });

    testWidgets('tocar num comprovante abre /receipts/:receiptId', (
      tester,
    ) async {
      stub(detail(receipts: rejectedPair()));
      when(
        () => h.receipts.fetchReceipt('receipt-note'),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await open(tester);

      final row = find.text('Enviado sex, 20/11 às 09:10');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(h.location, '/receipts/receipt-note');
    });

    testWidgets('Copiar chave copia a chave sem formatação', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      stub(detail());
      await open(tester);

      await tester.tap(buttonWithText<TextButton>(l10nPt.gamePixCopy));
      await tester.pumpAndSettle();
      expect(copied, '52998224725');
      expect(find.text(l10nPt.gamePixCopied), findsOneWidget);
    });

    testWidgets('jogo avulso: a pílula Avulso e o rótulo da multa', (
      tester,
    ) async {
      stub(detail(groupName: null, kind: ChargeKind.lateCancellationPenalty));
      await open(tester);

      expect(find.text(l10nPt.gameStandalone), findsOneWidget);
      expect(find.text(l10nPt.chargeKindLateCancellation), findsOneWidget);
    });

    testWidgets('Pago manual: chargePaidManual, sem a chave', (tester) async {
      stub(detail(status: ChargeStatus.paid, paidVia: PaymentMethod.manual));
      await open(tester);

      expect(find.text('Ana marcou como pago em sex, 20/11.'), findsOneWidget);
      expect(heroColor(tester), VoleiColors.dark.receive);
      expect(badge(tester), ChargeStatus.paid);
      expect(find.text(l10nPt.chargePayTo), findsNothing);
      expect(find.text(l10nPt.gamePixCopy), findsNothing);
    });

    testWidgets('Pago por comprovante: chargePaidReceipt', (tester) async {
      stub(detail(status: ChargeStatus.paid, paidVia: PaymentMethod.receipt));
      await open(tester);

      expect(find.text('Pago por comprovante em sex, 20/11.'), findsOneWidget);
      expect(find.text(l10nPt.chargePayTo), findsNothing);
      expect(find.text(l10nPt.receiptSend), findsNothing);
    });

    testWidgets('Em análise: o aviso e a chave, sem Enviar comprovante', (
      tester,
    ) async {
      stub(detail(status: ChargeStatus.underReview));
      await open(tester);

      expect(find.text('Ana vai conferir o seu comprovante.'), findsOneWidget);
      expect(find.text('CPF · 529.982.247-25'), findsOneWidget);
      expect(heroColor(tester), VoleiColors.dark.split);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(l10nPt.receiptSend), findsNothing);
    });

    testWidgets('Em análise, com o comprovante na lista e o selo Em análise', (
      tester,
    ) async {
      stub(
        detail(
          status: ChargeStatus.underReview,
          receipts: [
            ReceiptSummary(
              id: 'receipt-review',
              status: ReceiptStatus.underReview,
              createdAt: DateTime.utc(2026, 11, 20, 15, 5),
            ),
          ],
        ),
      );
      await open(tester);

      final row = find.text('Enviado sex, 20/11 às 12:05');
      await tester.scrollUntilVisible(row, 200);
      expect(row, findsOneWidget);
      // O selo do comprovante, além do selo do valor no topo.
      expect(
        find.descendant(
          of: find.byType(ReceiptStatusBadge),
          matching: find.text(l10nPt.receiptStatusUnderReview),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Isento: o motivo, sem a chave', (tester) async {
      stub(
        detail(
          status: ChargeStatus.waived,
          waiveReason: ChargeWaiveReason.manualWaiver,
        ),
      );
      await open(tester);

      expect(find.text(l10nPt.chargeWaivedManual), findsOneWidget);
      expect(heroColor(tester), appTheme.colorScheme.surfaceContainerHigh);
      expect(find.text(l10nPt.chargePayTo), findsNothing);
    });

    testWidgets('aberto pela Ana: estado não encontrado, com voltar', (
      tester,
    ) async {
      h.signedIn();
      when(
        () => h.games.fetchCharge(chargeId),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await open(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      await tester.tap(find.byTooltip(l10nPt.commonBack));
      await tester.pumpAndSettle();
      expect(h.location, '/charges');
    });

    testWidgets('puxar para baixo relê o valor', (tester) async {
      var value = detail();
      when(() => h.games.fetchCharge(chargeId)).thenAnswer((_) async => value);
      await open(tester);

      value = detail(status: ChargeStatus.paid, paidVia: PaymentMethod.manual);
      await tester.fling(
        find.text(l10nPt.chargePayTo),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ana marcou como pago em sex, 20/11.'), findsOneWidget);
    });

    testWidgets('voltar cai em Cobranças, que relê', (tester) async {
      stub(detail());
      await open(tester);
      clearInteractions(h.games);

      await tester.tap(find.byTooltip(l10nPt.commonBack));
      await tester.pumpAndSettle();
      expect(h.location, '/charges');
      verify(() => h.games.fetchMyCharges()).called(1);
    });
  });

  group('S88: fonte em 150%', () {
    for (final (name, build) in [
      ('Pendente', () => detail()),
      ('Em análise', () => detail(status: ChargeStatus.underReview)),
      ('Pendente com comprovantes', () => detail(receipts: rejectedPair())),
      (
        'Pago',
        () => detail(status: ChargeStatus.paid, paidVia: PaymentMethod.manual),
      ),
      (
        'Isento',
        () => detail(
          status: ChargeStatus.waived,
          waiveReason: ChargeWaiveReason.receiverChange,
        ),
      ),
    ]) {
      testWidgets('$name, sem overflow', (tester) async {
        stub(build());
        await open(tester, textScale: 1.5);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('S89: TalkBack', () {
    testWidgets('o título da tela, e os botões com rótulo e 48 dp', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      stub(detail(receipts: rejectedPair()));
      await open(tester);

      expect(find.bySemanticsLabel(l10nPt.chargeTitle), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
