import 'package:flutter/material.dart';

import 'form_fields.dart';

/// Campo de data ou de hora (design-system.md, 7.2; gamesNew.png): mostra o
/// valor escolhido (`21/11/2026`, `20:00`) e abre o seletor nativo no toque.
/// O erro aparece abaixo, com ícone, como nos outros campos. Sem [label], fica
/// sem rótulo (a hora do prazo, ao lado da data, sob o rótulo comum).
class PickerField extends StatelessWidget {
  const PickerField({
    required this.value,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.label,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.leading,
    super.key,
  });

  final String? label;

  /// Antes do valor (o quadrado com o ícone do grupo, gamesNew.png).
  final Widget? leading;

  /// O texto do valor, ou nulo com o campo vazio.
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  /// O rótulo para o TalkBack, já que o campo sem valor não tem texto.
  final String semanticLabel;
  final String? errorText;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) FieldLabel(label!),
        Semantics(
          button: true,
          label: semanticLabel,
          value: value,
          excludeSemantics: true,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
                width: hasError ? 2 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          value ?? '',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          FieldErrorText(errorText!)
        else if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              helperText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
