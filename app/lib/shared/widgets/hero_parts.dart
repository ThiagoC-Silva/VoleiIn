import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Partes do topo colorido (design-system.md, 7.8), do jogo e do valor a pagar.

/// Botão circular sobre o topo.
class HeroCircleButton extends StatelessWidget {
  const HeroCircleButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// Pílula do grupo, ou "Avulso".
class GroupPill extends StatelessWidget {
  const GroupPill({
    required this.label,
    required this.standalone,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String label;
  final bool standalone;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            standalone ? Symbols.person : Symbols.groups,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
