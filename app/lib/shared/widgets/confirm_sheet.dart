import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Confirmação destrutiva em sheet: título, consequência, botão destrutivo
/// sólido e botão de contorno para voltar (design-system.md, 7.15).
/// Devolve `true` só quando a pessoa confirma.
Future<bool> showDestructiveConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final colors = VoleiColors.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.destructive,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
