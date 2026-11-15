import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Selo em pílula (design-system.md, 3.3), sempre com texto: o status nunca é
/// só a cor (seção 8). O selo `neutral` é o dos papéis, como "Admin".
class VoleiBadge extends StatelessWidget {
  const VoleiBadge({required this.label, required this.tone, super.key});

  /// O selo neutro dos papéis (design-system.md, seção 4).
  factory VoleiBadge.neutral(BuildContext context, String label) =>
      VoleiBadge(label: label, tone: VoleiColors.of(context).neutral);

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: tone.text,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
