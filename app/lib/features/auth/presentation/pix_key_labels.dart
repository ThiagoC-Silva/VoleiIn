import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/pix_key_type.dart';

/// Rótulo, ícone e texto de erro de cada tipo de chave (docs/copy.md, 6.6;
/// profilePix-tipo.png).
extension PixKeyTypeLabel on PixKeyType {
  String label(AppLocalizations l10n) => switch (this) {
    PixKeyType.cpf => l10n.pixTypeCpf,
    PixKeyType.cnpj => l10n.pixTypeCnpj,
    PixKeyType.email => l10n.pixTypeEmail,
    PixKeyType.phone => l10n.pixTypePhone,
    PixKeyType.random => l10n.pixTypeRandom,
  };

  String invalidText(AppLocalizations l10n) => switch (this) {
    PixKeyType.cpf => l10n.pixInvalidCpf,
    PixKeyType.cnpj => l10n.pixInvalidCnpj,
    PixKeyType.email => l10n.pixInvalidEmail,
    PixKeyType.phone => l10n.pixInvalidPhone,
    PixKeyType.random => l10n.pixInvalidRandom,
  };

  IconData get icon => switch (this) {
    PixKeyType.cpf => Symbols.badge,
    PixKeyType.cnpj => Symbols.domain,
    PixKeyType.email => Symbols.alternate_email,
    PixKeyType.phone => Symbols.call,
    PixKeyType.random => Symbols.key,
  };
}
