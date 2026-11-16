import 'package:freezed_annotation/freezed_annotation.dart';

import '../../auth/domain/pix_key.dart';

part 'game_models.freezed.dart';

/// Enum `game_status` do banco (docs/modelo-dados.md, seção 3).
enum GameStatus {
  @JsonValue('open')
  open,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('completed')
  completed;

  /// Valor do banco.
  String get value => name;

  /// Valor desconhecido quebra a leitura de propósito: um status novo exige
  /// atualização do app (docs/arquitetura-app.md, seção 4).
  static GameStatus parse(String value) =>
      values.firstWhere((status) => status.value == value);

  /// Aberto ou Confirmado: os "Próximos" de Meus jogos (docs/ui/telas.md,
  /// seção 7).
  bool get isActive => this == open || this == confirmed;
}

/// Enum `participant_status` do banco.
enum ParticipantStatus {
  @JsonValue('active')
  active('active'),
  @JsonValue('left_after_start')
  leftAfterStart('left_after_start'),
  @JsonValue('cancelled')
  cancelled('cancelled'),
  @JsonValue('removed')
  removed('removed');

  const ParticipantStatus(this.value);

  /// Valor do banco.
  final String value;

  static ParticipantStatus parse(String value) =>
      values.firstWhere((status) => status.value == value);

  /// Ocupa vaga: `active` e `left_after_start` (docs/modelo-dados.md, seção
  /// 5; RN57).
  bool get takesSlot => this == active || this == leftAfterStart;
}

/// Card de jogo (docs/ui/telas.md, 7.1). As vagas ocupadas e a situação da
/// pessoa são contadas das linhas que o servidor devolve.
@freezed
abstract class GameSummary with _$GameSummary {
  const factory GameSummary({
    required String id,

    /// Nulo no jogo avulso.
    String? groupName,
    required String locationName,
    required DateTime startsAt,
    required DateTime endsAt,
    required GameStatus status,
    required int slotLimit,
    required int occupiedSlots,

    /// A passagem da pessoa que ocupa vaga (`active` ou `leftAfterStart`),
    /// ou nulo.
    ParticipantStatus? myStatus,

    /// 1, 2... pela ordem de `joined_at` da espera atual, ou nulo.
    int? myWaitlistPosition,
  }) = _GameSummary;
}

/// Linha da lista de presença (telas.md, 7.3): só as passagens que ocupam
/// vaga.
@freezed
abstract class GameParticipant with _$GameParticipant {
  const factory GameParticipant({
    required String userId,

    /// `coalesce(nickname, name)`, calculado no banco (RN100).
    required String displayName,
    String? photoPath,
    required ParticipantStatus status,
    required DateTime joinedAt,
  }) = _GameParticipant;
}

/// Linha da lista de espera atual (`left_at` nulo).
@freezed
abstract class WaitlistEntry with _$WaitlistEntry {
  const factory WaitlistEntry({
    required String userId,
    required String displayName,
    String? photoPath,
    required DateTime joinedAt,
  }) = _WaitlistEntry;
}

/// O jogo como o detalhe e a edição o leem (telas.md, 7.3 e 7.4).
@freezed
abstract class GameDetail with _$GameDetail {
  const GameDetail._();

  const factory GameDetail({
    required String id,
    String? groupId,
    String? groupName,
    required String locationName,
    String? mapsUrl,
    required DateTime cancellationDeadline,
    required DateTime startsAt,
    required DateTime endsAt,
    required int totalCents,
    required int slotLimit,
    required GameStatus status,
    required String receiverId,
    required String receiverName,
    String? receiverPhotoPath,

    /// De `get_profile_contact`: nulos para quem não pode ver a chave (RN102).
    PixKeyType? receiverPixKeyType,
    String? receiverPixKey,
    required List<GameParticipant> participants,
    required List<WaitlistEntry> waitlist,
    required List<String> adminIds,

    /// Se quem lê é membro do grupo do jogo. Falso no avulso.
    required bool isGroupMember,

    /// Quem lê, para as perguntas abaixo.
    required String viewerId,
  }) = _GameDetail;

  int get occupiedSlots => participants.where((p) => p.status.takesSlot).length;

  bool get isAdmin => adminIds.contains(viewerId);

  bool get isReceiver => receiverId == viewerId;

  bool isAdminUser(String userId) => adminIds.contains(userId);

  /// A passagem de quem lê que ocupa vaga, ou nulo.
  GameParticipant? get myParticipant {
    for (final participant in participants) {
      if (participant.userId == viewerId && participant.status.takesSlot) {
        return participant;
      }
    }
    return null;
  }

  /// A espera em ordem de `joined_at`.
  List<WaitlistEntry> get orderedWaitlist =>
      [...waitlist]..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

  /// 1, 2... na espera, ou nulo.
  int? get myWaitlistPosition {
    final index = orderedWaitlist.indexWhere((w) => w.userId == viewerId);
    return index < 0 ? null : index + 1;
  }
}

/// Grupo na sheet da criação (telas.md, 7.2).
@freezed
abstract class GameGroupOption with _$GameGroupOption {
  const factory GameGroupOption({required String id, required String name}) =
      _GameGroupOption;
}

/// Os dados de `create_game` e `update_game` (docs/contratos-api.md, seção
/// 4). Instantes em UTC. O limite só vai na criação: na edição, ele muda por
/// `set_slot_limit`.
@freezed
abstract class GameInput with _$GameInput {
  const factory GameInput({
    required String locationName,
    String? mapsUrl,
    required DateTime cancellationDeadline,
    required DateTime startsAt,
    required DateTime endsAt,
    required int totalCents,
    required int slotLimit,
  }) = _GameInput;
}
