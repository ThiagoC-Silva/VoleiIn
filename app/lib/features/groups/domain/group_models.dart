import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_models.freezed.dart';
part 'group_models.g.dart';

/// Enum `group_role` do banco (docs/modelo-dados.md, seção 3).
enum GroupRole {
  @JsonValue('admin')
  admin,
  @JsonValue('member')
  member;

  /// Valor do banco.
  String get value => name;

  /// Valor desconhecido quebra a leitura de propósito: um papel novo exige
  /// atualização do app (docs/arquitetura-app.md, seção 4).
  static GroupRole parse(String value) =>
      values.firstWhere((role) => role.value == value);
}

/// Linha de Meus grupos (docs/ui/telas.md, 6.1). `pendingCount` só conta para
/// quem é admin: o RLS não mostra as solicitações do grupo aos outros.
@freezed
abstract class GroupSummary with _$GroupSummary {
  const factory GroupSummary({
    required String id,
    required String name,
    String? photoPath,
    required int memberCount,
    required GroupRole role,
    required int pendingCount,
  }) = _GroupSummary;
}

/// O grupo como o detalhe e a sheet do convite o leem (telas.md, 6.4 e 6.5).
/// `inviteCode` nulo é o convite desativado.
@freezed
abstract class GroupDetail with _$GroupDetail {
  const GroupDetail._();

  const factory GroupDetail({
    required String id,
    required String name,
    String? photoPath,
    String? inviteCode,
    required int memberCount,
    required GroupRole myRole,
    required int pendingCount,
  }) = _GroupDetail;

  bool get isAdmin => myRole == GroupRole.admin;
}

/// Linha de Integrantes (telas.md, 6.6), com o perfil lido pelo contexto.
@freezed
abstract class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    required GroupRole role,
    required DateTime joinedAt,

    /// `coalesce(nickname, name)`, calculado no banco (RN100).
    required String displayName,
    String? photoPath,
  }) = _GroupMember;
}

/// Solicitação pendente (telas.md, 6.7), com o perfil de quem pediu
/// (RN107, exceção 2).
@freezed
abstract class JoinRequest with _$JoinRequest {
  const factory JoinRequest({
    required String id,
    required String userId,
    required DateTime createdAt,
    required String displayName,
    String? photoPath,
  }) = _JoinRequest;
}

/// Retorno da `preview-invite` para grupo (docs/contratos-api.md, seção 8).
@freezed
abstract class InvitePreview with _$InvitePreview {
  const factory InvitePreview({
    required String groupId,
    required String name,

    /// URL assinada de curta duração, nula sem foto.
    String? photoUrl,
    required bool isMember,
    required bool hasPendingRequest,
  }) = _InvitePreview;

  factory InvitePreview.fromJson(Map<String, dynamic> json) =>
      _$InvitePreviewFromJson(json);
}
