import 'package:freezed_annotation/freezed_annotation.dart';

import 'pix_key.dart';

part 'profile_private.freezed.dart';
part 'profile_private.g.dart';

/// Linha de `profile_private`: telefone e chave Pix (docs/modelo-dados.md, 4.1).
@freezed
abstract class ProfilePrivate with _$ProfilePrivate {
  const factory ProfilePrivate({
    /// Em E.164 (`+5586999991234`).
    String? phone,
    @Default(false) bool phoneVisible,
    PixKeyType? pixKeyType,

    /// Já normalizada pelo tipo (CPF só com dígitos, e-mail em minúsculas...).
    String? pixKey,
  }) = _ProfilePrivate;

  factory ProfilePrivate.fromJson(Map<String, dynamic> json) =>
      _$ProfilePrivateFromJson(json);
}
