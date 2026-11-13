import 'package:flutter/material.dart';

/// Quadrado de ícone, raio 14 (design-system.md, 6).
class IconSquare extends StatelessWidget {
  const IconSquare({
    required this.icon,
    this.size = 40,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size >= 56 ? 22 : 14),
      ),
      child: Icon(
        icon,
        size: size >= 56 ? 32 : 24,
        color: foreground ?? scheme.onSurface,
      ),
    );
  }
}
