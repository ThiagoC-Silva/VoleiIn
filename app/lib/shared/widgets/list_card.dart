import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Linhas num card `surface`, raio 22, com divisor recuado 70 entre elas
/// (design-system.md, 7.13; groups.png e groupMembers.png).
class ListCard extends StatelessWidget {
  const ListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 70, color: theme.dividerColor),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Linha de pessoa ou de grupo (design-system.md, 7.13): avatar de 44, nome em
/// Roboto 700 16, o selo ao lado do nome, subtítulo de 12 e, quando a linha
/// abre outra tela, a seta. Altura mínima de 64. Sem [onTap], não é tocável.
class ListRow extends StatelessWidget {
  const ListRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.badge,
    this.onTap,
    this.showChevron = false,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      ?badge,
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Symbols.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: content);
    return InkWell(onTap: onTap, child: content);
  }
}
