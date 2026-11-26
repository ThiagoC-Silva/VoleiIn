import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/payments/domain/receipt_models.dart';
import 'package:voleiin/features/payments/presentation/receipt_text.dart';

import '../../../helpers/receipt_fixtures.dart';
import '../../../helpers/test_app.dart';

/// Cenário U14 de docs/testes-referencia.md, seção 14.8: as linhas da
/// Conferência (docs/ui/telas.md, 9.4), a partir de `validation` e dos campos
/// lidos. O app só mostra o que o servidor conferiu.
void main() {
  group('U14: linhas da conferência', () {
    test('as quatro verdadeiras: quatro Confere, na ordem', () {
      final view = receiptCheckView(
        l10nPt,
        receiptDetail(
          validation: const ReceiptValidation(
            amount: true,
            recipient: true,
            paidAt: true,
            transactionId: true,
          ),
          extractedAmountCents: 2084,
          // Quinta, 19/11/2026, 22:20 em Fortaleza.
          extractedPaidAt: DateTime.utc(2026, 11, 20, 1, 20),
        ),
      );

      expect(view.skippedText, isNull);
      expect(
        [for (final row in view.rows) row.item],
        [
          ReceiptCheckItem.amount,
          ReceiptCheckItem.recipient,
          ReceiptCheckItem.paidAt,
          ReceiptCheckItem.transactionId,
        ],
      );
      expect(
        [for (final row in view.rows) row.label],
        [
          l10nPt.receiptCheckAmount,
          l10nPt.receiptCheckRecipient,
          l10nPt.receiptCheckDate,
          l10nPt.receiptCheckCode,
        ],
      );
      for (final row in view.rows) {
        expect(row.result, ReceiptCheckResult.ok, reason: row.label);
        expect(row.resultLabel, l10nPt.receiptCheckOk, reason: row.label);
      }
      expect(view.rows[0].expected, 'Esperado: ${formatCents(2084)}');
      expect(view.rows[0].read, 'Lido: ${formatCents(2084)}');
      expect(view.rows[1].expected, 'Esperado: Ana Souza Lima');
      expect(view.rows[1].read, 'Lido: ANA SOUZA LIMA');
      expect(
        view.rows[2].expected,
        'Esperado: A partir de qui, 19/11 às 20:00',
      );
      expect(view.rows[2].read, 'Lido: qui, 19/11 às 22:20');
      // O código do Pix não tem esperado.
      expect(view.rows[3].expected, isNull);
      expect(view.rows[3].read, 'Lido: $receiptPixId');
    });

    test('amount falso e paid_at nulo: Não confere no valor e Não lido na '
        'data', () {
      final view = receiptCheckView(l10nPt, receiptDetail());

      expect(view.skippedText, isNull);
      expect(
        [for (final row in view.rows) row.result],
        [
          ReceiptCheckResult.fail,
          ReceiptCheckResult.ok,
          ReceiptCheckResult.unread,
          ReceiptCheckResult.ok,
        ],
      );
      expect(view.rows[0].resultLabel, l10nPt.receiptCheckFail);
      expect(view.rows[2].resultLabel, l10nPt.receiptCheckUnread);
      expect(view.rows[0].read, 'Lido: ${formatCents(2080)}');
      // Sem leitura, só o esperado.
      expect(view.rows[2].read, isNull);
      expect(
        view.rows[0].semantics,
        l10nPt.receiptCheckSemantics(
          'Valor',
          'Não confere',
          'Esperado: ${formatCents(2084)}',
          'Lido: ${formatCents(2080)}',
        ),
      );
      expect(
        view.rows[2].semantics,
        'Data e hora, Não lido. Esperado: A partir de qui, 19/11 às 20:00.',
      );
      expect(
        view.rows[3].semantics,
        'Código do Pix, Confere. Lido: $receiptPixId.',
      );
    });

    test('a chave lida aparece junto do nome', () {
      final view = receiptCheckView(
        l10nPt,
        receiptDetail(extractedRecipientKey: '52998224725'),
      );
      expect(view.rows[1].read, 'Lido: ANA SOUZA LIMA · 52998224725');
    });

    test('skipped api_failed: sem linhas, só a frase receiptSkippedApi', () {
      final view = receiptCheckView(
        l10nPt,
        receiptDetail(
          validation: const ReceiptValidation(
            skipped: ReceiptSkipReason.apiFailed,
          ),
          extractedAmountCents: null,
          extractedRecipientName: null,
          transactionId: null,
        ),
      );
      expect(view.rows, isEmpty);
      expect(view.skippedText, l10nPt.receiptSkippedApi);
    });

    test('os outros motivos: receiptSkippedLimit e receiptSkippedFile', () {
      String? skipped(ReceiptSkipReason reason) => receiptCheckView(
        l10nPt,
        receiptDetail(validation: ReceiptValidation(skipped: reason)),
      ).skippedText;

      expect(skipped(ReceiptSkipReason.readLimit), l10nPt.receiptSkippedLimit);
      expect(
        skipped(ReceiptSkipReason.fileNotSupported),
        l10nPt.receiptSkippedFile,
      );
    });

    test('ReceiptValidation lê o JSON de validation', () {
      expect(
        ReceiptValidation.fromJson({
          'amount': false,
          'recipient': true,
          'paid_at': null,
          'transaction_id': true,
        }),
        const ReceiptValidation(
          amount: false,
          recipient: true,
          transactionId: true,
        ),
      );
      expect(
        ReceiptValidation.fromJson({
          'amount': null,
          'recipient': null,
          'paid_at': null,
          'transaction_id': null,
          'skipped': 'read_limit',
        }).skipped,
        ReceiptSkipReason.readLimit,
      );
    });
  });
}
