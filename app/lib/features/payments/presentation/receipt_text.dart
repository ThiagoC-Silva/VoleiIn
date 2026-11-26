import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/badge.dart';
import '../domain/receipt_models.dart';

// Textos e selos do comprovante (docs/copy.md, 10.3; design-system.md,
// seção 4). O status sempre tem texto, nunca só a cor.

String receiptStatusLabel(AppLocalizations l10n, ReceiptStatus status) =>
    switch (status) {
      ReceiptStatus.underReview => l10n.receiptStatusUnderReview,
      ReceiptStatus.approved => l10n.receiptStatusApproved,
      ReceiptStatus.rejected => l10n.receiptStatusRejected,
    };

/// Selo do comprovante: Em análise `info` com ampulheta, Aprovado `ok` com
/// visto e Recusado `bad` com xis (telas-fatia-6.md, Regras gerais).
class ReceiptStatusBadge extends StatelessWidget {
  const ReceiptStatusBadge({required this.status, super.key});

  final ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = VoleiColors.of(context);
    return VoleiBadge(
      label: receiptStatusLabel(AppLocalizations.of(context), status),
      tone: switch (status) {
        ReceiptStatus.underReview => colors.info,
        ReceiptStatus.approved => colors.ok,
        ReceiptStatus.rejected => colors.bad,
      },
      icon: switch (status) {
        ReceiptStatus.underReview => Symbols.hourglass_top,
        ReceiptStatus.approved => Symbols.check,
        ReceiptStatus.rejected => Symbols.close,
      },
    );
  }
}

/// A linha de apoio do comprovante na lista e na decisão: a observação do
/// recebedor ou o ID repetido. Nula nos outros casos.
String? receiptRejectionText(
  AppLocalizations l10n,
  ReceiptRejectionReason? reason,
  String? note,
) => switch (reason) {
  ReceiptRejectionReason.duplicateTransaction => l10n.receiptRejectedDuplicate,
  ReceiptRejectionReason.receiverRejected when note != null =>
    l10n.receiptNoteQuoted(note),
  _ => null,
};

/// Os itens da Conferência, na ordem da tela (docs/ui/telas.md, 9.4).
enum ReceiptCheckItem { amount, recipient, paidAt, transactionId }

/// O resultado de um item em `validation`: `true`, `false` ou nulo.
enum ReceiptCheckResult { ok, fail, unread }

/// Uma linha da Conferência, já com os textos.
class ReceiptCheckRow {
  const ReceiptCheckRow({
    required this.item,
    required this.label,
    required this.result,
    required this.resultLabel,
    required this.expected,
    required this.read,
    required this.semantics,
  });

  final ReceiptCheckItem item;
  final String label;
  final ReceiptCheckResult result;
  final String resultLabel;

  /// "Esperado: ...". Nulo no código do Pix.
  final String? expected;

  /// "Lido: ...". Nulo quando nada foi lido.
  final String? read;

  /// A linha inteira, para o TalkBack (S89).
  final String semantics;
}

/// A Conferência: as quatro linhas ou, sem leitura, só a frase do motivo.
class ReceiptCheckView {
  const ReceiptCheckView({required this.rows, this.skippedText});

  final List<ReceiptCheckRow> rows;
  final String? skippedText;
}

/// Monta a Conferência a partir de `validation` e dos campos lidos (U14). O
/// app não compara nada: só mostra o que o servidor conferiu.
ReceiptCheckView receiptCheckView(
  AppLocalizations l10n,
  ReceiptDetail receipt,
) {
  final validation = receipt.validation;
  final skipped = validation.skipped;
  if (skipped != null) {
    return ReceiptCheckView(
      rows: const [],
      skippedText: switch (skipped) {
        ReceiptSkipReason.readLimit => l10n.receiptSkippedLimit,
        ReceiptSkipReason.apiFailed => l10n.receiptSkippedApi,
        ReceiptSkipReason.fileNotSupported => l10n.receiptSkippedFile,
      },
    );
  }

  String dateTime(DateTime instant) =>
      l10n.receiptReadDateTime(formatShortDate(instant), formatTime(instant));

  final amount = receipt.extractedAmountCents;
  final paidAt = receipt.extractedPaidAt;
  final recipient = [
    ?receipt.extractedRecipientName,
    ?receipt.extractedRecipientKey,
  ];
  final code = receipt.transactionId;

  ReceiptCheckRow row(
    ReceiptCheckItem item,
    String label,
    bool? value, {
    String? expected,
    String? read,
  }) {
    final result = switch (value) {
      true => ReceiptCheckResult.ok,
      false => ReceiptCheckResult.fail,
      null => ReceiptCheckResult.unread,
    };
    final resultLabel = switch (result) {
      ReceiptCheckResult.ok => l10n.receiptCheckOk,
      ReceiptCheckResult.fail => l10n.receiptCheckFail,
      ReceiptCheckResult.unread => l10n.receiptCheckUnread,
    };
    final expectedText = expected == null
        ? null
        : l10n.receiptExpected(expected);
    final readText = read == null ? null : l10n.receiptRead(read);
    return ReceiptCheckRow(
      item: item,
      label: label,
      result: result,
      resultLabel: resultLabel,
      expected: expectedText,
      read: readText,
      semantics: _withoutEmptySentences(
        l10n.receiptCheckSemantics(
          label,
          resultLabel,
          expectedText ?? '',
          readText ?? '',
        ),
      ),
    );
  }

  return ReceiptCheckView(
    rows: [
      row(
        ReceiptCheckItem.amount,
        l10n.receiptCheckAmount,
        validation.amount,
        expected: formatCents(receipt.amountCents),
        read: amount == null ? null : formatCents(amount),
      ),
      row(
        ReceiptCheckItem.recipient,
        l10n.receiptCheckRecipient,
        validation.recipient,
        expected: receipt.receiverFullName,
        read: recipient.isEmpty ? null : recipient.join(' · '),
      ),
      row(
        ReceiptCheckItem.paidAt,
        l10n.receiptCheckDate,
        validation.paidAt,
        expected: l10n.receiptExpectedFrom(
          formatShortDate(receipt.startsAt),
          formatTime(receipt.startsAt),
        ),
        read: paidAt == null ? null : dateTime(paidAt),
      ),
      row(
        ReceiptCheckItem.transactionId,
        l10n.receiptCheckCode,
        validation.transactionId,
        read: code,
      ),
    ],
  );
}

/// Tira as frases vazias que sobram quando falta o esperado ou o lido:
/// "Código do Pix, Confere. . Lido: X." vira "Código do Pix, Confere. Lido:
/// X.".
String _withoutEmptySentences(String text) =>
    text.replaceAll(RegExp(r'\s*\.\s*(?=\.)'), '');
