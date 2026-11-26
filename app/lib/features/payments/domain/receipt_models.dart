import 'dart:typed_data';

import '../../../core/errors/error_code.dart';
import '../../../core/receipt_picker.dart';
import '../../../core/uuid.dart';
import '../../games/domain/charge_models.dart';

/// Enum `receipt_status` do banco (docs/modelo-dados.md, seção 3).
enum ReceiptStatus {
  underReview('under_review'),
  approved('approved'),
  rejected('rejected');

  const ReceiptStatus(this.value);

  /// Valor do banco.
  final String value;

  static ReceiptStatus parse(String value) =>
      values.firstWhere((status) => status.value == value);
}

/// Enum `receipt_rejection_reason` do banco.
enum ReceiptRejectionReason {
  duplicateTransaction('duplicate_transaction'),
  receiverRejected('receiver_rejected');

  const ReceiptRejectionReason(this.value);

  /// Valor do banco.
  final String value;

  static ReceiptRejectionReason parse(String value) =>
      values.firstWhere((reason) => reason.value == value);
}

/// O motivo de o app não ter lido o comprovante, em `validation.skipped`
/// (docs/comprovantes-ia.md, seção 5).
enum ReceiptSkipReason {
  apiFailed('api_failed'),
  readLimit('read_limit'),
  fileNotSupported('file_not_supported');

  const ReceiptSkipReason(this.value);

  final String value;

  static ReceiptSkipReason? tryParse(Object? value) {
    for (final reason in values) {
      if (reason.value == value) return reason;
    }
    return null;
  }
}

/// `receipts.validation`: o resultado de cada condição da RN88, gravado pelo
/// servidor. Nulo é "não lido" (docs/comprovantes-ia.md, seção 5).
class ReceiptValidation {
  const ReceiptValidation({
    this.amount,
    this.recipient,
    this.paidAt,
    this.transactionId,
    this.skipped,
  });

  factory ReceiptValidation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptValidation();
    return ReceiptValidation(
      amount: json['amount'] as bool?,
      recipient: json['recipient'] as bool?,
      paidAt: json['paid_at'] as bool?,
      transactionId: json['transaction_id'] as bool?,
      skipped: ReceiptSkipReason.tryParse(json['skipped']),
    );
  }

  final bool? amount;
  final bool? recipient;
  final bool? paidAt;
  final bool? transactionId;

  /// Preenchido quando não houve leitura, com as quatro nulas.
  final ReceiptSkipReason? skipped;

  @override
  bool operator ==(Object other) =>
      other is ReceiptValidation &&
      other.amount == amount &&
      other.recipient == recipient &&
      other.paidAt == paidAt &&
      other.transactionId == transactionId &&
      other.skipped == skipped;

  @override
  int get hashCode =>
      Object.hash(amount, recipient, paidAt, transactionId, skipped);
}

/// Uma linha da lista de comprovantes do valor a pagar (docs/ui/telas.md,
/// 9.2).
class ReceiptSummary {
  const ReceiptSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.receiverNote,
  });

  final String id;
  final ReceiptStatus status;
  final DateTime createdAt;
  final ReceiptRejectionReason? rejectionReason;
  final String? receiverNote;
}

/// O comprovante como a tela o lê (docs/ui/telas.md, 9.4). O RLS só o
/// devolve ao pagador e ao recebedor gravado nele (RF87).
class ReceiptDetail {
  const ReceiptDetail({
    required this.id,
    required this.chargeId,
    required this.status,
    required this.viewerIsReceiver,
    required this.payerId,
    required this.payerName,
    this.payerPhotoPath,
    required this.receiverId,
    required this.receiverName,
    required this.receiverFullName,
    this.receiverPhotoPath,
    required this.amountCents,
    required this.startsAt,
    required this.locationName,
    this.storagePath,
    required this.mimeType,
    this.fileDeletedAt,
    required this.validation,
    this.extractedAmountCents,
    this.extractedPaidAt,
    this.extractedRecipientName,
    this.extractedRecipientKey,
    this.transactionId,
    this.rejectionReason,
    this.receiverNote,
    this.decidedAt,
    this.decidedByName,
    required this.createdAt,
  });

  final String id;
  final String chargeId;
  final ReceiptStatus status;

  /// Quem lê é o `receiver_id` do comprovante: vê a conferência e decide.
  final bool viewerIsReceiver;
  final String payerId;

  /// `coalesce(nickname, name)` (RN100).
  final String payerName;
  final String? payerPhotoPath;
  final String receiverId;

  /// `coalesce(nickname, name)` (RN100).
  final String receiverName;

  /// `profiles.name`, o nome que a RN88b confere: o esperado de **Quem
  /// recebeu**.
  final String receiverFullName;
  final String? receiverPhotoPath;

  /// O valor a pagar.
  final int amountCents;

  /// O início do jogo: o esperado de **Data e hora** (RN88c).
  final DateTime startsAt;
  final String locationName;

  /// Nulo depois que o arquivo é apagado (RN91).
  final String? storagePath;
  final String mimeType;
  final DateTime? fileDeletedAt;
  final ReceiptValidation validation;
  final int? extractedAmountCents;
  final DateTime? extractedPaidAt;
  final String? extractedRecipientName;
  final String? extractedRecipientKey;
  final String? transactionId;
  final ReceiptRejectionReason? rejectionReason;
  final String? receiverNote;
  final DateTime? decidedAt;

  /// Nulo na decisão automática.
  final String? decidedByName;
  final DateTime createdAt;

  bool get isPdf => mimeType == ReceiptFile.pdfType;
}

/// A resposta de `process-receipt` (docs/contratos-api.md, seção 8).
class ReceiptResult {
  const ReceiptResult({
    required this.receiptId,
    required this.status,
    required this.chargeStatus,
    required this.autoReadsUsed,
  });

  factory ReceiptResult.fromJson(Map<String, dynamic> json) => ReceiptResult(
    receiptId: json['receipt_id'] as String,
    status: ReceiptStatus.parse(json['result'] as String),
    chargeStatus: ChargeStatus.parse(json['charge_status'] as String),
    autoReadsUsed: json['auto_reads_used'] as int,
  );

  final String receiptId;

  /// `rejected` é sempre o ID repetido (`DUPLICATE_TRANSACTION`).
  final ReceiptStatus status;
  final ChargeStatus chargeStatus;
  final int autoReadsUsed;
}

/// O arquivo escolhido, conferido contra a RN87 antes do envio: o tipo pela
/// extensão e o tamanho. O conteúdo é conferido pelo servidor.
class ReceiptFile {
  const ReceiptFile._({
    required this.name,
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });

  /// Lança `AppException(receiptTypeInvalid)` ou `(receiptTooLarge)`
  /// (docs/ui/telas.md, 9.3).
  factory ReceiptFile.fromPicked(PickedFile file) {
    final dot = file.name.lastIndexOf('.');
    final raw = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    final extension = raw == 'jpeg' ? 'jpg' : raw;
    final mimeType = _types[extension];
    if (mimeType == null || file.bytes.isEmpty) {
      throw const AppException(ErrorCode.receiptTypeInvalid);
    }
    if (file.bytes.length > maxBytes) {
      throw const AppException(ErrorCode.receiptTooLarge);
    }
    return ReceiptFile._(
      name: file.name,
      bytes: file.bytes,
      extension: extension,
      mimeType: mimeType,
    );
  }

  /// 10 MB (RN87; `receipts.size_bytes`).
  static const maxBytes = 10 * 1024 * 1024;

  static const pdfType = 'application/pdf';

  static const _types = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'pdf': pdfType,
  };

  final String name;
  final Uint8List bytes;
  final String extension;
  final String mimeType;

  bool get isPdf => mimeType == pdfType;

  int get size => bytes.length;
}

/// O caminho no bucket `receipts`: `{charge_id}/{uuid}.{ext}`, sempre com um
/// nome novo (docs/modelo-dados.md, seção 7; telas.md, 9.3).
String receiptStoragePath(String chargeId, String extension) =>
    '$chargeId/${uuidV4()}.$extension';
