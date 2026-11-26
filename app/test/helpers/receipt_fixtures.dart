import 'dart:typed_data';

import 'package:voleiin/core/receipt_picker.dart';
import 'package:voleiin/features/payments/domain/receipt_models.dart';

import 'games_fixtures.dart';
import 'harness.dart';

// Comprovantes dos cenários da etapa B da fatia 6 (docs/testes-referencia.md,
// seção 14; docs/ui/referencias/fatia-6/telas-fatia-6.md): o Fábio paga
// R$ 20,84 à Ana pelo jogo de quinta, 19/11, na Quadra do Sesc.

const receiptChargeId = '00000000-0000-0000-0000-000000000501';
const receiptId = '00000000-0000-0000-0000-000000000601';

/// Quinta, 19/11/2026, 20:00 em Fortaleza.
final receiptGameStart = DateTime.utc(2026, 11, 19, 23);

/// Sexta, 20/11/2026, 09:10 em Fortaleza.
final receiptSentAt = DateTime.utc(2026, 11, 20, 12, 10);

const receiptPixId = 'E18236120202611200115S0123456789';

const signedReceiptUrl =
    'http://127.0.0.1:54321/storage/v1/object/sign/receipts/r';

/// O comprovante como a tela o lê. Por padrão, Em análise, aberto pela Ana,
/// com o valor lido errado (R$ 20,80) e a data não lida, como no receipt.png.
ReceiptDetail receiptDetail({
  String id = receiptId,
  ReceiptStatus status = ReceiptStatus.underReview,
  bool viewerIsReceiver = true,
  String? storagePath =
      '$receiptChargeId/00000000-0000-4000-8000-000000000001.png',
  String mimeType = 'image/png',
  DateTime? fileDeletedAt,
  ReceiptValidation validation = const ReceiptValidation(
    amount: false,
    recipient: true,
    transactionId: true,
  ),
  int? extractedAmountCents = 2080,
  DateTime? extractedPaidAt,
  String? extractedRecipientName = 'ANA SOUZA LIMA',
  String? extractedRecipientKey,
  String? transactionId = receiptPixId,
  ReceiptRejectionReason? rejectionReason,
  String? receiverNote,
  DateTime? decidedAt,
  String? decidedByName,
}) => ReceiptDetail(
  id: id,
  chargeId: receiptChargeId,
  status: status,
  viewerIsReceiver: viewerIsReceiver,
  payerId: fabioId,
  payerName: 'Fábio',
  receiverId: anaId,
  receiverName: 'Ana',
  receiverFullName: 'Ana Souza Lima',
  amountCents: 2084,
  startsAt: receiptGameStart,
  locationName: 'Quadra do Sesc',
  storagePath: storagePath,
  mimeType: mimeType,
  fileDeletedAt: fileDeletedAt,
  validation: validation,
  extractedAmountCents: extractedAmountCents,
  extractedPaidAt: extractedPaidAt,
  extractedRecipientName: extractedRecipientName,
  extractedRecipientKey: extractedRecipientKey,
  transactionId: transactionId,
  rejectionReason: rejectionReason,
  receiverNote: receiverNote,
  decidedAt: decidedAt,
  decidedByName: decidedByName,
  createdAt: receiptSentAt,
);

/// PNG de 1 × 1, para a miniatura decodificar sem erro.
final onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

PickedFile pickedImage() => PickedFile(name: 'pix.png', bytes: onePixelPng);

/// O PDF do briefing: "comprovante.pdf", 184 KB.
PickedFile pickedPdf() =>
    PickedFile(name: 'comprovante.pdf', bytes: Uint8List(184 * 1024));
