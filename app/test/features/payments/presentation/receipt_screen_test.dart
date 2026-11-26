import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/payments/domain/receipt_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/receipt_fixtures.dart';
import '../../../helpers/test_app.dart';

/// Cenários S81, S82, S83, S88 e S89 da etapa B de docs/testes-referencia.md,
/// seção 14 (docs/ui/telas.md, 9.4; receipt.png, receipt-pagador.png e
/// receipt-recusar.png): o comprovante do Fábio, visto por ele e pela Ana.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  /// O comprovante relido do servidor: cada leitura chama [read] de novo.
  void stub(ReceiptDetail Function() read) {
    when(() => h.receipts.fetchReceipt(receiptId))
        .thenAnswer((_) async => read());
  }

  void reviewWorks() {
    when(
      () => h.receipts.review(
        receiptId: any(named: 'receiptId'),
        approve: any(named: 'approve'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});
  }

  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    // Por Cobranças, como a linha de Para conferir.
    await h.pumpApp(tester, location: '/charges', textScale: textScale);
    await h.push(tester, '/receipts/$receiptId');
  }

  Future<void> tapIn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  group('S81: o comprovante, visto pelo Fábio', () {
    setUp(() => h.signedIn(userId: fabioId));

    testWidgets('Em análise: "Para Ana", o selo e a imagem, sem botões e sem '
        'a conferência', (tester) async {
      stub(() => receiptDetail(viewerIsReceiver: false));
      await open(tester);

      expect(find.text(l10nPt.receiptTitle), findsOneWidget);
      expect(find.text(l10nPt.splitOwedTo('Ana')), findsOneWidget);
      expect(find.text('qui, 19/11 · Quadra do Sesc'), findsOneWidget);
      expect(find.text(formatCents(2084)), findsOneWidget);
      expect(find.text(l10nPt.receiptStatusUnderReview), findsOneWidget);
      expect(find.byKey(const Key('receiptImage')), findsOneWidget);
      verify(() => h.receipts.fileUrl(any())).called(1);
      expect(find.text(l10nPt.receiptCheckTitle), findsNothing);
      expect(find.text(l10nPt.receiptApprove), findsNothing);
      expect(find.text(l10nPt.receiptReject), findsNothing);
    });

    testWidgets('recusado com observação: a decisão e a observação', (
      tester,
    ) async {
      stub(
        () => receiptDetail(
          viewerIsReceiver: false,
          status: ReceiptStatus.rejected,
          rejectionReason: ReceiptRejectionReason.receiverRejected,
          receiverNote: 'O valor está errado, faltam 4 centavos.',
          decidedAt: DateTime.utc(2026, 11, 20, 13),
          decidedByName: 'Ana',
        ),
      );
      await open(tester);

      expect(find.text(l10nPt.receiptStatusRejected), findsOneWidget);
      expect(find.text('Recusado por Ana em sex, 20/11.'), findsOneWidget);
      expect(
        find.text(
          l10nPt.receiptNoteQuoted('O valor está errado, faltam 4 centavos.'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10nPt.receiptApprove), findsNothing);
    });

    testWidgets('recusado por ID repetido: receiptRejectedDuplicate', (
      tester,
    ) async {
      stub(
        () => receiptDetail(
          viewerIsReceiver: false,
          status: ReceiptStatus.rejected,
          rejectionReason: ReceiptRejectionReason.duplicateTransaction,
          decidedAt: receiptSentAt,
        ),
      );
      await open(tester);

      expect(find.text(l10nPt.receiptRejectedDuplicate), findsOneWidget);
    });

    testWidgets('arquivo apagado: receiptFileDeleted com a data, sem URL', (
      tester,
    ) async {
      stub(
        () => receiptDetail(
          viewerIsReceiver: false,
          status: ReceiptStatus.rejected,
          rejectionReason: ReceiptRejectionReason.receiverRejected,
          receiverNote: 'Faltam 4 centavos.',
          decidedAt: DateTime.utc(2026, 11, 20, 13),
          decidedByName: 'Ana',
          storagePath: null,
          // Domingo, 20/12/2026, 04:00 em Fortaleza.
          fileDeletedAt: DateTime.utc(2026, 12, 20, 7),
        ),
      );
      await open(tester);

      expect(find.text('O arquivo foi apagado em dom, 20/12.'), findsOneWidget);
      expect(find.byKey(const Key('receiptImage')), findsNothing);
      verifyNever(() => h.receipts.fileUrl(any()));
    });

    testWidgets('PDF: Abrir PDF abre a URL assinada fora do app', (
      tester,
    ) async {
      stub(
        () => receiptDetail(
          viewerIsReceiver: false,
          storagePath:
              '$receiptChargeId/00000000-0000-4000-8000-000000000002.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await open(tester);

      expect(find.byKey(const Key('receiptImage')), findsNothing);
      await tapIn(
        tester,
        buttonWithText<OutlinedButton>(l10nPt.receiptOpenPdf),
      );
      expect(h.links.opened, [Uri.parse(signedReceiptUrl)]);
    });

    testWidgets('a URL assinada falha: receiptFileError com Tentar de novo', (
      tester,
    ) async {
      var attempts = 0;
      when(() => h.receipts.fileUrl(any())).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const AppException(ErrorCode.noConnection);
        return signedReceiptUrl;
      });
      stub(() => receiptDetail(viewerIsReceiver: false));
      await open(tester);

      expect(find.text(l10nPt.receiptFileError), findsOneWidget);
      await tapIn(tester, find.text(l10nPt.commonTryAgain));
      expect(find.text(l10nPt.receiptFileError), findsNothing);
      expect(find.byKey(const Key('receiptImage')), findsOneWidget);
    });

    testWidgets('tocar na imagem abre em tela cheia', (tester) async {
      stub(() => receiptDetail(viewerIsReceiver: false));
      await open(tester);

      await tapIn(tester, find.byKey(const Key('receiptImage')));
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('aberto por quem não pode ver: estado não encontrado', (
      tester,
    ) async {
      when(
        () => h.receipts.fetchReceipt(receiptId),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await open(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
    });
  });

  group('S82: o comprovante, visto pela Ana', () {
    testWidgets('Em análise com amount falso e paid_at nulo: a Conferência', (
      tester,
    ) async {
      stub(receiptDetail);
      await open(tester);

      // O cabeçalho mostra quem pagou.
      expect(find.text('Fábio'), findsOneWidget);
      expect(find.text(l10nPt.receiptCheckTitle), findsOneWidget);
      expect(find.text(l10nPt.receiptCheckHint), findsOneWidget);
      for (final label in [
        l10nPt.receiptCheckAmount,
        l10nPt.receiptCheckRecipient,
        l10nPt.receiptCheckDate,
        l10nPt.receiptCheckCode,
      ]) {
        await tester.scrollUntilVisible(find.text(label), 200);
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(l10nPt.receiptCheckFail), findsOneWidget);
      expect(find.text(l10nPt.receiptCheckUnread), findsOneWidget);
      expect(find.text(l10nPt.receiptCheckOk), findsNWidgets(2));
      expect(find.text('Esperado: ${formatCents(2084)}'), findsOneWidget);
      expect(find.text('Lido: ${formatCents(2080)}'), findsOneWidget);
      expect(find.text('Esperado: Ana Souza Lima'), findsOneWidget);
      expect(find.text('Lido: ANA SOUZA LIMA'), findsOneWidget);
      expect(
        find.text('Esperado: A partir de qui, 19/11 às 20:00'),
        findsOneWidget,
      );
      expect(find.text('Lido: $receiptPixId'), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.receiptApprove),
        findsOneWidget,
      );
      expect(
        buttonWithText<OutlinedButton>(l10nPt.receiptReject),
        findsOneWidget,
      );
    });

    testWidgets('com skipped: a frase do motivo, sem linhas', (tester) async {
      stub(
        () => receiptDetail(
          validation: const ReceiptValidation(
            skipped: ReceiptSkipReason.readLimit,
          ),
          extractedAmountCents: null,
          extractedRecipientName: null,
          transactionId: null,
        ),
      );
      await open(tester);

      expect(find.text(l10nPt.receiptSkippedLimit), findsOneWidget);
      expect(find.text(l10nPt.receiptCheckAmount), findsNothing);
      // A decisão continua possível.
      expect(
        buttonWithText<FilledButton>(l10nPt.receiptApprove),
        findsOneWidget,
      );
    });

    testWidgets('Aprovado automático: receiptDecidedAuto, sem botões', (
      tester,
    ) async {
      stub(
        () => receiptDetail(
          status: ReceiptStatus.approved,
          validation: const ReceiptValidation(
            amount: true,
            recipient: true,
            paidAt: true,
            transactionId: true,
          ),
          extractedAmountCents: 2084,
          extractedPaidAt: DateTime.utc(2026, 11, 20, 1, 20),
          decidedAt: DateTime.utc(2026, 11, 20, 1, 21),
        ),
      );
      await open(tester);

      expect(find.text(l10nPt.receiptStatusApproved), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Aprovado pelo app em qui, 19/11.'),
        200,
      );
      expect(find.text('Aprovado pelo app em qui, 19/11.'), findsOneWidget);
      expect(find.text(l10nPt.receiptApprove), findsNothing);
      expect(find.text(l10nPt.receiptReject), findsNothing);
    });

    testWidgets('aprovado pela Ana: receiptDecidedApproved', (tester) async {
      stub(
        () => receiptDetail(
          status: ReceiptStatus.approved,
          decidedAt: DateTime.utc(2026, 11, 20, 13),
          decidedByName: 'Ana',
        ),
      );
      await open(tester);

      await tester.scrollUntilVisible(
        find.text('Aprovado por Ana em sex, 20/11.'),
        200,
      );
      expect(find.text('Aprovado por Ana em sex, 20/11.'), findsOneWidget);
    });
  });

  group('S83: aprovar e recusar', () {
    testWidgets('Aprovar e confirmar: review_receipt(true), '
        'receiptApprovedByYou, e volta', (tester) async {
      reviewWorks();
      stub(receiptDetail);
      await open(tester);

      await tapIn(tester, buttonWithText<FilledButton>(l10nPt.receiptApprove));
      expect(inSheet(find.text(l10nPt.receiptApproveTitle)), findsOneWidget);
      expect(
        inSheet(find.text(l10nPt.receiptApproveBody(formatCents(2084)))),
        findsOneWidget,
      );
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptApprove)),
      );

      verify(() => h.receipts.review(receiptId: receiptId, approve: true))
          .called(1);
      expect(find.text(l10nPt.receiptApprovedByYou), findsOneWidget);
      expect(h.location, '/charges');
    });

    testWidgets('Voltar na confirmação não aprova', (tester) async {
      reviewWorks();
      stub(receiptDetail);
      await open(tester);

      await tapIn(tester, buttonWithText<FilledButton>(l10nPt.receiptApprove));
      await tapIn(
        tester,
        inSheet(buttonWithText<OutlinedButton>(l10nPt.commonBack)),
      );
      verifyNever(
        () => h.receipts.review(
          receiptId: any(named: 'receiptId'),
          approve: any(named: 'approve'),
          note: any(named: 'note'),
        ),
      );
      expect(h.location, '/receipts/$receiptId');
    });

    testWidgets('Recusar sem observação: receiptNoteRequired, sem chamar', (
      tester,
    ) async {
      reviewWorks();
      stub(receiptDetail);
      await open(tester);

      await tapIn(tester, buttonWithText<OutlinedButton>(l10nPt.receiptReject));
      expect(inSheet(find.text(l10nPt.receiptRejectTitle)), findsOneWidget);
      expect(
        inSheet(find.text(l10nPt.receiptRejectBody('Fábio'))),
        findsOneWidget,
      );
      await tester.enterText(inSheet(find.byType(TextField)), '   ');
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptReject)),
      );

      expect(inSheet(find.text(l10nPt.receiptNoteRequired)), findsOneWidget);
      verifyNever(
        () => h.receipts.review(
          receiptId: any(named: 'receiptId'),
          approve: any(named: 'approve'),
          note: any(named: 'note'),
        ),
      );
    });

    testWidgets('com 201 caracteres: o campo para em 200', (tester) async {
      stub(receiptDetail);
      await open(tester);

      await tapIn(tester, buttonWithText<OutlinedButton>(l10nPt.receiptReject));
      await tester.enterText(inSheet(find.byType(TextField)), 'a' * 201);
      await tester.pump();

      final field = tester.widget<TextField>(inSheet(find.byType(TextField)));
      expect(field.controller!.text.length, 200);
      expect(inSheet(find.text('200/200')), findsOneWidget);
    });

    testWidgets('com texto: review_receipt(false, texto), '
        'receiptRejectedByYou, e volta', (tester) async {
      reviewWorks();
      stub(receiptDetail);
      await open(tester);

      await tapIn(tester, buttonWithText<OutlinedButton>(l10nPt.receiptReject));
      await tester.enterText(
        inSheet(find.byType(TextField)),
        '  O valor está errado, faltam 4 centavos.  ',
      );
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptReject)),
      );

      verify(
        () => h.receipts.review(
          receiptId: receiptId,
          approve: false,
          note: 'O valor está errado, faltam 4 centavos.',
        ),
      ).called(1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10nPt.receiptRejectedByYou), findsOneWidget);
      expect(h.location, '/charges');
    });

    testWidgets('RECEIPT_NOT_UNDER_REVIEW: SnackBar, e a tela relê', (
      tester,
    ) async {
      var current = receiptDetail();
      when(
        () => h.receipts.review(
          receiptId: any(named: 'receiptId'),
          approve: any(named: 'approve'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async {
        current = receiptDetail(
          status: ReceiptStatus.approved,
          decidedAt: DateTime.utc(2026, 11, 20, 13),
          decidedByName: 'Ana',
        );
        throw const AppException(ErrorCode.receiptNotUnderReview);
      });
      stub(() => current);
      await open(tester);

      await tapIn(tester, buttonWithText<FilledButton>(l10nPt.receiptApprove));
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptApprove)),
      );

      expect(find.text(l10nPt.errorReceiptNotUnderReview), findsOneWidget);
      expect(h.location, '/receipts/$receiptId');
      expect(find.text(l10nPt.receiptStatusApproved), findsOneWidget);
      expect(find.text(l10nPt.receiptApprove), findsNothing);
    });
  });

  group('S88: fonte em 150%', () {
    for (final (name, viewerIsReceiver) in [
      ('Ana, Em análise', true),
      ('Fábio, Em análise', false),
    ]) {
      testWidgets('$name, sem overflow', (tester) async {
        stub(() => receiptDetail(viewerIsReceiver: viewerIsReceiver));
        await open(tester, textScale: 1.5);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Fábio, recusado com o arquivo apagado, sem overflow', (
      tester,
    ) async {
      h.signedIn(userId: fabioId);
      stub(
        () => receiptDetail(
          viewerIsReceiver: false,
          status: ReceiptStatus.rejected,
          rejectionReason: ReceiptRejectionReason.receiverRejected,
          receiverNote: 'O valor está errado, faltam 4 centavos.',
          decidedAt: DateTime.utc(2026, 11, 20, 13),
          decidedByName: 'Ana',
          storagePath: null,
          fileDeletedAt: DateTime.utc(2026, 12, 20, 7),
        ),
      );
      await open(tester, textScale: 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a sheet de recusa e a confirmação, sem overflow', (
      tester,
    ) async {
      stub(receiptDetail);
      await open(tester, textScale: 1.5);

      await tapIn(tester, buttonWithText<OutlinedButton>(l10nPt.receiptReject));
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      await tapIn(tester, buttonWithText<FilledButton>(l10nPt.receiptApprove));
      expect(tester.takeException(), isNull);
    });
  });

  group('S89: TalkBack', () {
    testWidgets('a imagem com receiptImageLabel, a linha lida inteira, e os '
        'botões com rótulo e 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      stub(receiptDetail);
      await open(tester);

      expect(find.bySemanticsLabel(l10nPt.receiptImageLabel), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          l10nPt.receiptCheckSemantics(
            'Valor',
            'Não confere',
            'Esperado: ${formatCents(2084)}',
            'Lido: ${formatCents(2080)}',
          ),
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
