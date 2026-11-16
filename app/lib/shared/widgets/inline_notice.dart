import 'package:flutter/material.dart';

import 'icon_square.dart';

/// Aviso em linha (design-system.md, 7.14): card `surface` com um quadrado de
/// ícone de 40, raio 14, na cor do assunto, e o texto em `body.md`.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
    this.action,
    this.iconColor,
    super.key,
  });

  final IconData icon;

  /// Cor do assunto (por exemplo, `wait` para o que aguarda alguém).
  final Color color;
  final String text;

  /// Linha em negrito acima do texto ("Cerca de R\$ 10,00 por pessoa").
  final String? title;

  /// Botão abaixo do texto, na largura do card (gamesNew-semPix.png).
  final Widget? action;

  /// Cor do ícone; por padrão, o navy dos blocos coloridos.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconSquare(
                icon: icon,
                background: color,
                foreground: iconColor ?? theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      text,
                      style: title == null
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
