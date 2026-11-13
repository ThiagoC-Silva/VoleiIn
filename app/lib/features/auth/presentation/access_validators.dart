import '../../../l10n/app_localizations.dart';

/// O que o app confere sem o servidor nas telas de acesso e de perfil
/// (docs/ui/telas.md, regras comuns da seção 5): campo vazio, nome com até 80
/// caracteres e senha com pelo menos 8. O formato do e-mail é do Auth.
class AccessValidators {
  const AccessValidators(this.l10n);

  final AppLocalizations l10n;

  static const nameMax = 80;
  static const nicknameMax = 30;
  static const passwordMin = 8;

  String? name(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.authNameRequired;
    if (name.length > nameMax) return l10n.authNameTooLong;
    return null;
  }

  String? email(String? value) =>
      (value ?? '').trim().isEmpty ? l10n.authEmailRequired : null;

  /// Senha que já existe: só não pode ficar vazia.
  String? currentPassword(String? value) =>
      (value ?? '').isEmpty ? l10n.authPasswordRequired : null;

  /// Senha nova: pelo menos 8 caracteres, como o Supabase Auth.
  String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return l10n.authPasswordRequired;
    if (password.length < passwordMin) return l10n.authPasswordTooShort;
    return null;
  }
}
