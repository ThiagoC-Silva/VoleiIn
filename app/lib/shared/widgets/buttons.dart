import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Botão principal com o estado carregando (design-system.md, 7.1): mantém a
/// cor, troca o texto por um indicador e bloqueia novo toque.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Destrutivo sólido: só no botão final de uma confirmação destrutiva.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final background = destructive
        ? colors.destructive
        : theme.colorScheme.primary;
    final foreground = destructive ? Colors.white : theme.colorScheme.onPrimary;

    ButtonStyle? style;
    if (destructive) {
      style = FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
      );
    }
    if (loading) {
      style = (style ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStatePropertyAll(background),
        foregroundColor: WidgetStatePropertyAll(foreground),
      );
    }

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: loading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: foreground,
              ),
            )
          : Text(label, textAlign: TextAlign.center),
    );
  }
}

/// Botão destrutivo de contorno: borda neutra e texto `errorText`. Ação
/// destrutiva que ainda pede confirmação (design-system.md, 7.1).
class DestructiveOutlinedButton extends StatelessWidget {
  const DestructiveOutlinedButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
