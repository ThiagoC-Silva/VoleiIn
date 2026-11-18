import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Um card do trio de números (design-system.md, 7.10): rótulo, número em
/// Bebas Neue e legenda. Com [color], o bloco de significado com texto navy.
class GameTrioCard extends StatelessWidget {
  const GameTrioCard({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final String caption;

  /// Cor de significado, com o texto navy dos blocos.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final text = color == null ? theme.colorScheme.onSurface : colors.onBlock;
    final soft = color == null
        ? theme.colorScheme.onSurfaceVariant
        : colors.onBlock;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: soft)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: 26,
                color: text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(color: soft),
          ),
        ],
      ),
    );
  }
}
