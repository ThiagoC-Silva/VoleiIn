import 'package:flutter/material.dart';

import 'icon_square.dart';

/// Aviso em linha (design-system.md, 7.14): card `surface` com um quadrado de
/// ícone de 40, raio 14, na cor do assunto, e o texto em `body.md`.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
    super.key,
  });

  final IconData icon;

  /// Cor do assunto (por exemplo, `wait` para o que aguarda alguém).
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconSquare(
            icon: icon,
            background: color,
            foreground: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
