import 'package:freezed_annotation/freezed_annotation.dart';

import 'pix_key_type.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// Linha de `profiles` (docs/modelo-dados.md, 4.1). `displayName` vem do banco:
/// o apelido ou, sem ele, o nome (RN100).
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String name,
    String? nickname,
    required String displayName,
    String? photoPath,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// Linha de `profile_private`: só o dono lê (docs/rls-matriz.md, Fatia 2).
@freezed
abstract class ProfilePrivate with _$ProfilePrivate {
  const factory ProfilePrivate({
    required String userId,
    String? phone,
    @Default(false) bool phoneVisible,
    PixKeyType? pixKeyType,
    String? pixKey,
  }) = _ProfilePrivate;

  factory ProfilePrivate.fromJson(Map<String, dynamic> json) =>
      _$ProfilePrivateFromJson(json);
}

/// O que as telas do próprio perfil leem: as duas linhas e o e-mail da conta.
@freezed
abstract class OwnProfile with _$OwnProfile {
  const factory OwnProfile({
    required Profile profile,
    required ProfilePrivate private,
    required String email,
    required bool hasEmailPassword,
  }) = _OwnProfile;
}
