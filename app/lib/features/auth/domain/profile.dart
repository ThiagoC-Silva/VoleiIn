import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// Linha de `profiles` (docs/modelo-dados.md, 4.1).
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String name,
    String? nickname,

    /// `coalesce(nickname, name)`, calculado no banco (RN100).
    required String displayName,
    String? photoPath,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
