import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/pix_key.dart';

/// Rótulo do enum `pix_key_type` (docs/copy.md, 6.6).
String pixKeyTypeLabel(AppLocalizations l10n, PixKeyType type) =>
    switch (type) {
      PixKeyType.cpf => l10n.pixTypeCpf,
      PixKeyType.cnpj => l10n.pixTypeCnpj,
      PixKeyType.email => l10n.pixTypeEmail,
      PixKeyType.phone => l10n.pixTypePhone,
      PixKeyType.random => l10n.pixTypeRandom,
    };

/// Ícone de cada tipo no menu (profilePix-tipo.png).
IconData pixKeyTypeIcon(PixKeyType type) => switch (type) {
  PixKeyType.cpf => Symbols.badge,
  PixKeyType.cnpj => Symbols.domain,
  PixKeyType.email => Symbols.alternate_email,
  PixKeyType.phone => Symbols.call,
  PixKeyType.random => Symbols.key,
};
