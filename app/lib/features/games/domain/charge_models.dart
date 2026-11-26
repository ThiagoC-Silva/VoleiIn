import '../../auth/domain/pix_key.dart';
import '../../payments/domain/receipt_models.dart';
import 'game_models.dart';

/// Enum `charge_kind` do banco (docs/modelo-dados.md, seção 3).
enum ChargeKind {
  share('share'),
  absencePenalty('absence_penalty'),
  lateCancellationPenalty('late_cancellation_penalty');

  const ChargeKind(this.value);

  /// Valor do banco.
  final String value;

  static ChargeKind parse(String value) =>
      values.firstWhere((kind) => kind.value == value);

  bool get isPenalty => this != share;
}

/// Enum `charge_status` do banco.
enum ChargeStatus {
  pending('pending'),
  underReview('under_review'),
  paid('paid'),
  waived('waived');

  const ChargeStatus(this.value);

  /// Valor do banco.
  final String value;

  static ChargeStatus parse(String value) =>
      values.firstWhere((status) => status.value == value);
}

/// Enum `charge_waive_reason` do banco.
enum ChargeWaiveReason {
  manualWaiver('manual_waiver'),
  receiverChange('receiver_change');

  const ChargeWaiveReason(this.value);

  /// Valor do banco.
  final String value;

  static ChargeWaiveReason parse(String value) =>
      values.firstWhere((reason) => reason.value == value);
}

/// Enum `payment_method` do banco.
enum PaymentMethod {
  manual('manual'),
  receipt('receipt');

  const PaymentMethod(this.value);

  /// Valor do banco.
  final String value;

  static PaymentMethod parse(String value) =>
      values.firstWhere((method) => method.value == value);
}

/// Um valor a pagar do jogo (`charges`), com os nomes do pagador e do
/// recebedor a quem ele é devido (RN32). O RLS decide quais chegam
/// (docs/rls-matriz.md, fatia 5).
class GameCharge {
  const GameCharge({
    required this.id,
    required this.payerId,
    required this.payerName,
    this.payerPhotoPath,
    required this.receiverId,
    required this.receiverName,
    required this.kind,
    required this.amountCents,
    required this.status,
    this.waiveReason,
    this.paidVia,
    this.reviewReceiptId,
  });

  final String id;
  final String payerId;

  /// `coalesce(nickname, name)` (RN100).
  final String payerName;
  final String? payerPhotoPath;
  final String receiverId;
  final String receiverName;
  final ChargeKind kind;
  final int amountCents;
  final ChargeStatus status;
  final ChargeWaiveReason? waiveReason;

  /// Só no valor Pago.
  final PaymentMethod? paidVia;

  /// O comprovante Em análise, quando quem lê é o recebedor dele: abre
  /// **Conferir comprovante** (docs/ui/telas.md, 9.5).
  final String? reviewReceiptId;
}

/// O valor a pagar como o pagador o lê, com o jogo e a chave Pix do recebedor
/// do valor (RN32; docs/ui/telas.md, 9.2).
class ChargeDetail {
  const ChargeDetail({
    required this.id,
    required this.gameId,
    this.groupName,
    required this.startsAt,
    required this.locationName,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoPath,
    this.receiverPixKeyType,
    this.receiverPixKey,
    required this.kind,
    required this.amountCents,
    required this.status,
    this.waiveReason,
    this.paidAt,
    this.paidVia,
    this.receipts = const [],
    this.autoReadsUsed = 0,
  });

  final String id;
  final String gameId;

  /// Nulo no jogo avulso.
  final String? groupName;
  final DateTime startsAt;
  final String locationName;
  final String receiverId;

  /// `coalesce(nickname, name)` (RN100).
  final String receiverName;
  final String? receiverPhotoPath;

  /// Nulos quando o servidor não mostra a chave (RN102).
  final PixKeyType? receiverPixKeyType;
  final String? receiverPixKey;
  final ChargeKind kind;
  final int amountCents;
  final ChargeStatus status;
  final ChargeWaiveReason? waiveReason;

  /// Só no valor Pago.
  final DateTime? paidAt;
  final PaymentMethod? paidVia;

  /// Os comprovantes do valor, em qualquer ordem: a tela os mostra do mais
  /// novo para o mais antigo (telas.md, 9.2).
  final List<ReceiptSummary> receipts;

  /// Leituras automáticas usadas, até 3 (RN86).
  final int autoReadsUsed;
}

/// Retorno de `preview_complete_game` e de `complete_game`
/// (docs/contratos-api.md, seção 5). O app só mostra estes números.
class CompletionPreview {
  const CompletionPreview({
    required this.shareCents,
    required this.totalToReceiveCents,
    required this.receiverCoveredCents,
    required this.uncoveredSlots,
    required this.penaltiesExempted,
  });

  factory CompletionPreview.fromJson(Map<String, dynamic> json) =>
      CompletionPreview(
        shareCents: json['share_cents'] as int,
        totalToReceiveCents: json['total_to_receive_cents'] as int,
        receiverCoveredCents: json['receiver_covered_cents'] as int,
        uncoveredSlots: json['uncovered_slots'] as int,
        penaltiesExempted: json['penalties_exempted'] as int,
      );

  final int shareCents;
  final int totalToReceiveCents;

  /// Pode ser negativo, pelo arredondamento (R04).
  final int receiverCoveredCents;
  final int uncoveredSlots;
  final int penaltiesExempted;
}

/// Enum `removal_reason` do banco (docs/modelo-dados.md, seção 3).
enum RemovalReason {
  byAdmin('by_admin'),
  leftGroup('left_group'),
  accountDeleted('account_deleted');

  const RemovalReason(this.value);

  /// Valor do banco.
  final String value;

  static RemovalReason parse(String value) =>
      values.firstWhere((reason) => reason.value == value);
}

/// Enum `absence_source` do banco.
enum AbsenceSource {
  leftAfterStart('left_after_start'),
  markedByAdmin('marked_by_admin');

  const AbsenceSource(this.value);

  /// Valor do banco.
  final String value;

  static AbsenceSource parse(String value) =>
      values.firstWhere((source) => source.value == value);
}

/// Uma passagem da pessoa pela lista, em qualquer status, para os motivos do
/// Rateio (docs/ui/telas.md, 8.3) e o card "Sua participação" (8.1).
class GamePassage {
  const GamePassage({
    required this.userId,
    required this.displayName,
    this.photoPath,
    required this.status,
    required this.joinedAt,
    this.leftAt,
    this.lateCancellation = false,
    this.cancellationVoidedAt,
    this.lateCancellationExempt = false,
    this.removalReason,
    this.absent = false,
    this.absenceSource,
  });

  final String userId;
  final String displayName;
  final String? photoPath;
  final ParticipantStatus status;
  final DateTime joinedAt;

  /// Cancelamento, saída ou remoção.
  final DateTime? leftAt;
  final bool lateCancellation;

  /// A pessoa voltou antes do início: o cancelamento não conta (RN56).
  final DateTime? cancellationVoidedAt;

  /// Multa isentada na conclusão (RN62).
  final bool lateCancellationExempt;
  final RemovalReason? removalReason;
  final bool absent;
  final AbsenceSource? absenceSource;
}

/// O Rateio do jogo concluído (docs/ui/telas.md, 8.3).
class GameSplit {
  const GameSplit({
    required this.game,
    required this.charges,
    required this.passages,
  });

  final GameDetail game;

  /// Só os que o RLS devolve: os próprios, ou todos para o recebedor e os
  /// admins do jogo (RN76).
  final List<GameCharge> charges;
  final List<GamePassage> passages;
}

/// Um valor `pending` ou `under_review` em que quem lê é o pagador ou o
/// recebedor, com o jogo, para a aba Cobranças (RF75, RF76;
/// docs/ui/telas.md, 8.5).
class ChargeLine {
  const ChargeLine({
    required this.id,
    required this.gameId,
    required this.startsAt,
    required this.locationName,
    required this.payerId,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhotoPath,
    required this.kind,
    required this.amountCents,
    required this.status,
  });

  final String id;
  final String gameId;
  final DateTime startsAt;
  final String locationName;
  final String payerId;
  final String receiverId;

  /// `coalesce(nickname, name)` (RN100).
  final String receiverName;
  final String? receiverPhotoPath;
  final ChargeKind kind;
  final int amountCents;
  final ChargeStatus status;
}

/// O que quem lê tem a receber num jogo: uma linha por jogo (decisão de
/// 18/11/2026; telas.md, 8.5).
class GameToReceive {
  const GameToReceive({
    required this.gameId,
    required this.startsAt,
    required this.locationName,
    required this.payerIds,
    required this.amountCents,
  });

  final String gameId;
  final DateTime startsAt;
  final String locationName;
  final Set<String> payerIds;
  final int amountCents;
}

/// Um comprovante Em análise que quem lê confere, com o valor e o jogo, para
/// **Para conferir** (docs/ui/telas.md, 9.1).
class ReviewLine {
  const ReviewLine({
    required this.receiptId,
    required this.chargeId,
    required this.payerId,
    required this.payerName,
    this.payerPhotoPath,
    required this.startsAt,
    required this.locationName,
    required this.amountCents,
    required this.sentAt,
  });

  final String receiptId;
  final String chargeId;
  final String payerId;

  /// `coalesce(nickname, name)` (RN100).
  final String payerName;
  final String? payerPhotoPath;
  final DateTime startsAt;
  final String locationName;
  final int amountCents;

  /// Quando o comprovante foi enviado: a ordem da seção.
  final DateTime sentAt;
}

/// A aba Cobranças: os valores a pagar e a receber de quem lê, somando todos
/// os jogos. O app só soma `amount_cents` já gravados, em inteiros
/// (contratos-api.md, seção 9).
class ChargesOverview {
  ChargesOverview({
    required this.viewerId,
    required List<ChargeLine> lines,
    List<ReviewLine> toReview = const [],
  }) : toReview = [...toReview]
         ..sort((a, b) {
           final bySent = a.sentAt.compareTo(b.sentAt);
           return bySent != 0 ? bySent : a.receiptId.compareTo(b.receiptId);
         }),
       toPay = [
         for (final line in lines)
           if (line.payerId == viewerId) line,
       ]..sort(_byGame),
       toReceive = _receivable(viewerId, lines);

  final String viewerId;

  /// Os comprovantes Em análise que quem lê confere, do envio mais antigo
  /// para o mais novo (telas.md, 9.1).
  final List<ReviewLine> toReview;

  /// Os valores em que quem lê é o pagador, do jogo mais antigo para o mais
  /// recente.
  final List<ChargeLine> toPay;

  /// Os jogos em que quem lê é o recebedor de algum valor, na mesma ordem.
  final List<GameToReceive> toReceive;

  int get toPayCents => toPay.fold(0, (sum, line) => sum + line.amountCents);

  int get toPayGames => {for (final line in toPay) line.gameId}.length;

  int get toReceiveCents =>
      toReceive.fold(0, (sum, game) => sum + game.amountCents);

  /// Pessoas diferentes que devem a quem lê, em todos os jogos.
  int get toReceivePeople =>
      {for (final game in toReceive) ...game.payerIds}.length;

  /// O contador da aba: os valores Pendentes a pagar (telas.md, 8.5).
  int get pendingToPayCount =>
      toPay.where((line) => line.status == ChargeStatus.pending).length;

  bool get isEmpty => toPay.isEmpty && toReceive.isEmpty;

  static int _byGame(ChargeLine a, ChargeLine b) {
    final byStart = a.startsAt.compareTo(b.startsAt);
    return byStart != 0 ? byStart : a.gameId.compareTo(b.gameId);
  }

  static List<GameToReceive> _receivable(
    String viewerId,
    List<ChargeLine> lines,
  ) {
    final byGame = <String, List<ChargeLine>>{};
    for (final line in lines) {
      if (line.receiverId == viewerId) {
        byGame.putIfAbsent(line.gameId, () => []).add(line);
      }
    }
    final games = [
      for (final entry in byGame.entries)
        GameToReceive(
          gameId: entry.key,
          startsAt: entry.value.first.startsAt,
          locationName: entry.value.first.locationName,
          payerIds: {for (final line in entry.value) line.payerId},
          amountCents: entry.value.fold(0, (sum, l) => sum + l.amountCents),
        ),
    ];
    return games..sort((a, b) {
      final byStart = a.startsAt.compareTo(b.startsAt);
      return byStart != 0 ? byStart : a.gameId.compareTo(b.gameId);
    });
  }
}
