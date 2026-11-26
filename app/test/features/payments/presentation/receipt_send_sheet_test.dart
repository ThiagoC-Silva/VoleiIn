import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/receipt_picker.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/features/payments/domain/receipt_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/receipt_fixtures.dart';
import '../../../helpers/test_app.dart';

/// Cenários S78, S79, S80, S88 e S89 da etapa B de docs/testes-referencia.md,
/// seção 14 (docs/ui/telas.md, 9.3; charge-enviar1.png a charge-enviar4*.png):
/// a sheet Enviar comprovante, sobre o valor a pagar do Fábio à Ana.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn(userId: fabioId);
    registerFallbackValue(Uint8List(0));
  });

  ChargeDetail detail({
    ChargeStatus status = ChargeStatus.pending,
    int autoReadsUsed = 0,
    PaymentMethod? paidVia,
  }) => ChargeDetail(
    id: receiptChargeId,
    gameId: finishedId,
    groupName: 'Vôlei de Quinta',
    startsAt: receiptGameStart,
    locationName: 'Quadra do Sesc',
    receiverId: anaId,
    receiverName: 'Ana',
    receiverPixKeyType: PixKeyType.cpf,
    receiverPixKey: '52998224725',
    kind: ChargeKind.share,
    amountCents: 2084,
    status: status,
    paidAt: paidVia == null ? null : receiptSentAt,
    paidVia: paidVia,
    autoReadsUsed: autoReadsUsed,
  );

  /// O valor relido do servidor: cada leitura chama [read] de novo.
  void stub(ChargeDetail Function() read) {
    when(() => h.games.fetchCharge(receiptChargeId))
        .thenAnswer((_) async => read());
  }

  void uploadWorks() {
    when(
      () => h.receipts.upload(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async {});
  }

  void processAnswers(Future<ReceiptResult> Function() answer) {
    when(
      () => h.receipts.process(
        chargeId: any(named: 'chargeId'),
        storagePath: any(named: 'storagePath'),
      ),
    ).thenAnswer((_) => answer());
  }

  ReceiptResult result(ReceiptStatus status, {ChargeStatus? chargeStatus}) =>
      ReceiptResult(
        receiptId: receiptId,
        status: status,
        chargeStatus:
            chargeStatus ??
            switch (status) {
              ReceiptStatus.approved => ChargeStatus.paid,
              ReceiptStatus.underReview => ChargeStatus.underReview,
              ReceiptStatus.rejected => ChargeStatus.pending,
            },
        autoReadsUsed: 1,
      );

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  Finder sheetText(String text) => inSheet(find.text(text));

  Future<void> tapIn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Abre o valor a pagar e a sheet.
  Future<void> openSheet(
    WidgetTester tester, {
    ChargeDetail Function()? charge,
    double textScale = 1,
  }) async {
    stub(charge ?? detail);
    await h.pumpApp(
      tester,
      location: '/charges/$receiptChargeId',
      textScale: textScale,
    );
    await tapIn(tester, buttonWithText<FilledButton>(l10nPt.receiptSend));
  }

  Future<void> chooseImage(WidgetTester tester, {PickedFile? file}) async {
    h.receiptPicker.images.add(file ?? pickedImage());
    await tapIn(tester, sheetText(l10nPt.receiptPickImage));
  }

  group('S78: escolher o arquivo', () {
    testWidgets('passo 1: o título, a frase e as duas opções', (tester) async {
      await openSheet(tester);

      expect(sheetText(l10nPt.receiptSend), findsOneWidget);
      expect(sheetText(l10nPt.receiptSendBody), findsOneWidget);
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
      expect(sheetText(l10nPt.receiptPickPdf), findsOneWidget);
      expect(sheetText(l10nPt.receiptNoMoreReads('Ana')), findsNothing);
    });

    testWidgets('uma imagem: a miniatura, Enviar e Escolher outro', (
      tester,
    ) async {
      await openSheet(tester);
      await chooseImage(tester);

      expect(
        inSheet(find.byKey(const Key('receiptThumbnail'))),
        findsOneWidget,
      );
      expect(
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
        findsOneWidget,
      );
      expect(
        inSheet(buttonWithText<TextButton>(l10nPt.receiptPickOther)),
        findsOneWidget,
      );
    });

    testWidgets('um PDF: o nome e o tamanho', (tester) async {
      await openSheet(tester);
      h.receiptPicker.pdfs.add(pickedPdf());
      await tapIn(tester, sheetText(l10nPt.receiptPickPdf));

      expect(sheetText('comprovante.pdf'), findsOneWidget);
      expect(sheetText('184 KB'), findsOneWidget);
      expect(inSheet(find.byKey(const Key('receiptThumbnail'))), findsNothing);
    });

    testWidgets('Escolher outro volta ao passo 1', (tester) async {
      await openSheet(tester);
      await chooseImage(tester);
      await tapIn(
        tester,
        inSheet(buttonWithText<TextButton>(l10nPt.receiptPickOther)),
      );

      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
    });

    testWidgets('desistir na galeria fica no passo 1', (tester) async {
      await openSheet(tester);
      await tapIn(tester, sheetText(l10nPt.receiptPickImage));

      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
    });

    testWidgets('um arquivo de 11 MB: errorReceiptTooLarge, sem enviar', (
      tester,
    ) async {
      await openSheet(tester);
      h.receiptPicker.pdfs.add(
        PickedFile(name: 'grande.pdf', bytes: Uint8List(11 * 1024 * 1024)),
      );
      await tapIn(tester, sheetText(l10nPt.receiptPickPdf));

      expect(sheetText(l10nPt.errorReceiptTooLarge), findsOneWidget);
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
      verifyNever(
        () => h.receipts.upload(
          path: any(named: 'path'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      );
    });

    testWidgets('um .docx: errorReceiptTypeInvalid, sem enviar', (
      tester,
    ) async {
      await openSheet(tester);
      h.receiptPicker.pdfs.add(
        PickedFile(name: 'pix.docx', bytes: Uint8List(1024)),
      );
      await tapIn(tester, sheetText(l10nPt.receiptPickPdf));

      expect(sheetText(l10nPt.errorReceiptTypeInvalid), findsOneWidget);
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
    });

    testWidgets('auto_reads_used 3: o aviso receiptNoMoreReads', (
      tester,
    ) async {
      await openSheet(tester, charge: () => detail(autoReadsUsed: 3));

      expect(sheetText(l10nPt.receiptNoMoreReads('Ana')), findsOneWidget);
      // O envio continua possível: vai para a análise (RN86).
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
    });
  });

  group('S79: enviar e ler', () {
    testWidgets('o arquivo vai para <charge>/<uuid>.<ext>, e depois '
        'process-receipt é chamada uma vez', (tester) async {
      uploadWorks();
      processAnswers(() async => result(ReceiptStatus.approved));
      await openSheet(tester);
      await chooseImage(tester);
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );

      final path =
          verify(
                () => h.receipts.upload(
                  path: captureAny(named: 'path'),
                  bytes: any(named: 'bytes'),
                  mimeType: 'image/png',
                ),
              ).captured.single
              as String;
      expect(
        path,
        matches(
          RegExp(
            '^$receiptChargeId/'
            r'[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}\.png$',
          ),
        ),
      );
      verify(
        () => h.receipts.process(chargeId: receiptChargeId, storagePath: path),
      ).called(1);
    });

    testWidgets('lendo: receiptReading; tocar fora e voltar não fecham, e não '
        'há botão', (tester) async {
      uploadWorks();
      final reading = Completer<ReceiptResult>();
      processAnswers(() => reading.future);
      await openSheet(tester);
      await chooseImage(tester);
      await tester.tap(
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );
      await tester.pump();
      await tester.pump();

      expect(sheetText(l10nPt.receiptReading), findsOneWidget);
      expect(inSheet(find.byType(FilledButton)), findsNothing);
      expect(inSheet(find.byType(TextButton)), findsNothing);

      // Fora da sheet, no topo da tela.
      await tester.tapAt(const Offset(180, 40));
      await tester.pump(const Duration(milliseconds: 500));
      expect(sheetText(l10nPt.receiptReading), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sheetText(l10nPt.receiptReading), findsOneWidget);

      reading.complete(result(ReceiptStatus.approved));
      await tester.pumpAndSettle();
      expect(sheetText(l10nPt.receiptApproved), findsOneWidget);
      verify(
        () => h.receipts.process(
          chargeId: any(named: 'chargeId'),
          storagePath: any(named: 'storagePath'),
        ),
      ).called(1);
    });
  });

  group('S80: o resultado', () {
    Future<void> send(WidgetTester tester) async {
      await chooseImage(tester);
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );
    }

    testWidgets('approved: receiptApproved; Pronto fecha, e a tela relê', (
      tester,
    ) async {
      var current = detail();
      uploadWorks();
      processAnswers(() async {
        current = detail(
          status: ChargeStatus.paid,
          paidVia: PaymentMethod.receipt,
        );
        return result(ReceiptStatus.approved);
      });
      await openSheet(tester, charge: () => current);
      await send(tester);

      expect(sheetText(l10nPt.receiptApproved), findsOneWidget);
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptDone)),
      );
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Pago por comprovante em sex, 20/11.'), findsOneWidget);
    });

    testWidgets('under_review: receiptUnderReview com "Ana"', (tester) async {
      uploadWorks();
      processAnswers(() async => result(ReceiptStatus.underReview));
      await openSheet(tester);
      await send(tester);

      expect(sheetText(l10nPt.receiptUnderReview('Ana')), findsOneWidget);
      expect(
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptDone)),
        findsOneWidget,
      );
    });

    testWidgets('rejected: receiptDuplicate; Enviar outro volta ao passo 1, e '
        'Fechar fecha', (tester) async {
      uploadWorks();
      processAnswers(() async => result(ReceiptStatus.rejected));
      await openSheet(tester);
      await send(tester);

      expect(sheetText(l10nPt.receiptDuplicate), findsOneWidget);
      expect(
        inSheet(buttonWithText<OutlinedButton>(l10nPt.receiptClose)),
        findsOneWidget,
      );
      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendOther)),
      );
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);

      await send(tester);
      await tapIn(
        tester,
        inSheet(buttonWithText<OutlinedButton>(l10nPt.receiptClose)),
      );
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('CHARGE_NOT_PENDING: SnackBar, a sheet fecha e a tela relê', (
      tester,
    ) async {
      uploadWorks();
      processAnswers(
        () async => throw const AppException(ErrorCode.chargeNotPending),
      );
      await openSheet(tester);
      clearInteractions(h.games);
      await send(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10nPt.errorChargeNotPending), findsOneWidget);
      verify(() => h.games.fetchCharge(receiptChargeId)).called(1);
    });

    testWidgets('sem conexão no meio: receiptResultUnknown, fecha e relê', (
      tester,
    ) async {
      uploadWorks();
      processAnswers(
        () async => throw const AppException(ErrorCode.noConnection),
      );
      await openSheet(tester);
      clearInteractions(h.games);
      await send(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10nPt.receiptResultUnknown), findsOneWidget);
      verify(() => h.games.fetchCharge(receiptChargeId)).called(1);
    });

    testWidgets('RECEIPT_TYPE_INVALID do servidor: o erro no passo 1', (
      tester,
    ) async {
      uploadWorks();
      processAnswers(
        () async => throw const AppException(ErrorCode.receiptTypeInvalid),
      );
      await openSheet(tester);
      await send(tester);

      expect(sheetText(l10nPt.errorReceiptTypeInvalid), findsOneWidget);
      expect(sheetText(l10nPt.receiptPickImage), findsOneWidget);
    });

    testWidgets('falha no envio ao bucket: receiptUploadFailed no passo 2, '
        'com Tentar de novo', (tester) async {
      var attempts = 0;
      when(
        () => h.receipts.upload(
          path: any(named: 'path'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const AppException(ErrorCode.noConnection);
      });
      processAnswers(() async => result(ReceiptStatus.approved));
      await openSheet(tester);
      await send(tester);

      expect(sheetText(l10nPt.receiptUploadFailed), findsOneWidget);
      expect(
        inSheet(find.byKey(const Key('receiptThumbnail'))),
        findsOneWidget,
      );
      verifyNever(
        () => h.receipts.process(
          chargeId: any(named: 'chargeId'),
          storagePath: any(named: 'storagePath'),
        ),
      );

      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.commonTryAgain)),
      );
      expect(sheetText(l10nPt.receiptApproved), findsOneWidget);
    });

    testWidgets('fechar no passo 1: a tela relê', (tester) async {
      await openSheet(tester);
      clearInteractions(h.games);

      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      verify(() => h.games.fetchCharge(receiptChargeId)).called(1);
    });
  });

  group('S88: fonte em 150%', () {
    testWidgets('os quatro passos, sem overflow', (tester) async {
      uploadWorks();
      final reading = Completer<ReceiptResult>();
      processAnswers(() => reading.future);
      await openSheet(
        tester,
        charge: () => detail(autoReadsUsed: 3),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);

      await chooseImage(tester);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );
      await tester.tap(
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      reading.complete(result(ReceiptStatus.rejected));
      await tester.pumpAndSettle();
      expect(sheetText(l10nPt.receiptDuplicate), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('o PDF e o resultado em análise, sem overflow', (tester) async {
      uploadWorks();
      processAnswers(() async => result(ReceiptStatus.underReview));
      await openSheet(tester, textScale: 1.5);
      h.receiptPicker.pdfs.add(pickedPdf());
      await tapIn(tester, sheetText(l10nPt.receiptPickPdf));
      expect(tester.takeException(), isNull);

      await tapIn(
        tester,
        inSheet(buttonWithText<FilledButton>(l10nPt.receiptSendAction)),
      );
      expect(sheetText(l10nPt.receiptUnderReview('Ana')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('S89: TalkBack', () {
    testWidgets('opções e botões com rótulo e 48 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      await openSheet(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await chooseImage(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });
}
