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

/// Uma passagem da pessoa pela lista, em qualquer status, para os motivos do
/// Rateio (docs/ui/telas.md, 8.3).
class GamePassage {
  const GamePassage({
    required this.userId,
    required this.displayName,
    this.photoPath,
    required this.status,
    required this.joinedAt,
    this.lateCancellation = false,
    this.lateCancellationExempt = false,
    this.absent = false,
  });

  final String userId;
  final String displayName;
  final String? photoPath;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final bool lateCancellation;

  /// Multa isentada na conclusão (RN62).
  final bool lateCancellationExempt;
  final bool absent;
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
