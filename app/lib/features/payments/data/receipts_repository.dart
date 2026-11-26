import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../domain/receipt_models.dart';

/// Comprovantes da etapa B da fatia 6 (RF78 a RF83, RF86, RF87;
/// specs/010-pagamentos-etapa-b).
///
/// Lê `receipts` direto, limitado pelo RLS: só o pagador e o recebedor do
/// comprovante (docs/rls-matriz.md, fatia 6). O arquivo vai ao bucket
/// `receipts` pela escrita direta (contratos-api.md, seção 9), a leitura é da
/// Edge Function `process-receipt` e a decisão, de `review_receipt`.
class ReceiptsRepository {
  ReceiptsRepository(this._db);

  final SupabaseClient _db;

  static const _bucket = 'receipts';

  /// URL assinada de 10 minutos, pedida ao abrir (docs/ui/telas.md, 9.4).
  static const _signedUrlSeconds = 600;

  /// Folga sobre os 30 s da leitura (RNF04): sem resposta, o app não sabe se
  /// o servidor gravou (telas.md, 9.3).
  static const _processTimeout = Duration(seconds: 45);

  String get _uid => _db.auth.currentUser!.id;

  Future<ReceiptDetail> fetchReceipt(String receiptId) => guard(() async {
    _requireUuid(receiptId);
    final row = await _db
        .from('receipts')
        .select(
          'id, charge_id, payer_id, receiver_id, storage_path, mime_type, '
          'status, extracted_amount_cents, extracted_paid_at, '
          'extracted_recipient_name, extracted_recipient_key, transaction_id, '
          'validation, rejection_reason, receiver_note, decided_at, '
          'file_deleted_at, created_at, '
          'charge:charges!receipts_charge_id_fkey(amount_cents, '
          'game:games!charges_game_id_fkey(location_name, starts_at)), '
          'payer:profiles!receipts_payer_id_fkey(display_name, photo_path), '
          'receiver:profiles!receipts_receiver_id_fkey(name, display_name, '
          'photo_path), '
          'decider:profiles!receipts_decided_by_fkey(display_name)',
        )
        .eq('id', receiptId)
        .maybeSingle();
    // Os admins do jogo não veem o comprovante (RF87): sem pista.
    if (row == null) throw const AppException(ErrorCode.notFound);

    final charge = row['charge'] as Map;
    final game = charge['game'] as Map;
    final payer = row['payer'] as Map?;
    final receiver = row['receiver'] as Map?;
    final decider = row['decider'] as Map?;
    final reason = row['rejection_reason'] as String?;
    final validation = row['validation'];
    return ReceiptDetail(
      id: row['id'] as String,
      chargeId: row['charge_id'] as String,
      status: ReceiptStatus.parse(row['status'] as String),
      viewerIsReceiver: row['receiver_id'] == _uid,
      payerId: row['payer_id'] as String,
      payerName: payer?['display_name'] as String? ?? '',
      payerPhotoPath: payer?['photo_path'] as String?,
      receiverId: row['receiver_id'] as String,
      receiverName: receiver?['display_name'] as String? ?? '',
      receiverFullName: receiver?['name'] as String? ?? '',
      receiverPhotoPath: receiver?['photo_path'] as String?,
      amountCents: charge['amount_cents'] as int,
      startsAt: _instant(game['starts_at']),
      locationName: game['location_name'] as String,
      storagePath: row['storage_path'] as String?,
      mimeType: row['mime_type'] as String,
      fileDeletedAt: _instantOrNull(row['file_deleted_at']),
      validation: ReceiptValidation.fromJson(
        validation is Map ? Map<String, dynamic>.from(validation) : null,
      ),
      extractedAmountCents: row['extracted_amount_cents'] as int?,
      extractedPaidAt: _instantOrNull(row['extracted_paid_at']),
      extractedRecipientName: row['extracted_recipient_name'] as String?,
      extractedRecipientKey: row['extracted_recipient_key'] as String?,
      transactionId: row['transaction_id'] as String?,
      rejectionReason: reason == null
          ? null
          : ReceiptRejectionReason.parse(reason),
      receiverNote: row['receiver_note'] as String?,
      decidedAt: _instantOrNull(row['decided_at']),
      decidedByName: decider?['display_name'] as String?,
      createdAt: _instant(row['created_at']),
    );
  });

  Future<String> fileUrl(String path) => guard(
    () => _db.storage.from(_bucket).createSignedUrl(path, _signedUrlSeconds),
  );

  /// Envia o arquivo para [path] (`receiptStoragePath`), sem sobrescrever.
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) => guard(() async {
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
  });

  /// `process-receipt` (contratos-api.md, seção 8): lê o arquivo já enviado e
  /// devolve o resultado. Os erros vêm em `{ "error": { "code" } }`.
  Future<ReceiptResult> process({
    required String chargeId,
    required String storagePath,
  }) => guard(() async {
    final response = await _db.functions
        .invoke(
          'process-receipt',
          body: {'charge_id': chargeId, 'storage_path': storagePath},
        )
        .timeout(_processTimeout);
    return ReceiptResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  });

  /// `review_receipt` (contratos-api.md, seção 6). Na recusa, [note] é a
  /// observação, já sem os espaços das pontas.
  Future<void> review({
    required String receiptId,
    required bool approve,
    String? note,
  }) => guard(() async {
    await _db.rpc(
      'review_receipt',
      params: {'p_receipt_id': receiptId, 'p_approve': approve, 'p_note': note},
    );
  });

  static DateTime _instant(Object? value) =>
      DateTime.parse(value as String).toUtc();

  static DateTime? _instantOrNull(Object? value) =>
      value == null ? null : _instant(value);
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

/// O parâmetro da rota vem de fora: um ID que não é UUID é "não encontrado".
void _requireUuid(String id) {
  if (!_uuid.hasMatch(id)) throw const AppException(ErrorCode.notFound);
}

final receiptsRepositoryProvider = Provider<ReceiptsRepository>(
  (ref) => ReceiptsRepository(ref.watch(supabaseProvider)),
);
