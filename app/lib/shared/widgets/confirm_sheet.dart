import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'buttons.dart';

/// Sheet com alça e cantos de cima 28 (design-system.md, 7.15). O conteúdo
/// rola com a fonte em 150%.
Future<T?> showVoleiSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: const Color.fromRGBO(5, 10, 25, .72),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: builder(context),
    ),
  );
}

/// Confirmação destrutiva: título, a consequência, o botão destrutivo sólido
/// e o de contorno "Voltar" (design-system.md, 7.15). Verdadeiro ao confirmar.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showVoleiSheet<bool>(context, (context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        PrimaryButton(
          label: confirmLabel,
          destructive: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonBack),
        ),
      ],
    );
  });
  return confirmed ?? false;
}
