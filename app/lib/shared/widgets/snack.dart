import 'package:flutter/material.dart';

import '../../core/errors/error_text.dart';
import '../../l10n/app_localizations.dart';

/// Mensagem de uma ação (design-system.md, 7.16): `SnackBar` flutuante.
void showSnack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// O texto do erro da ação, pelo código (docs/copy.md).
void showErrorSnack(BuildContext context, Object error) =>
    showSnack(context, errorTextFor(AppLocalizations.of(context), error));
