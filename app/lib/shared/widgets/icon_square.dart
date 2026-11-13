import 'package:flutter/material.dart';

/// Quadrado de ícone, raio 14 (design-system.md, 6 e 7.14).
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
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size >= 56 ? 18 : 14),
      ),
      child: ExcludeSemantics(
        child: Icon(
          icon,
          size: size >= 56 ? 32 : 22,
          color: foreground ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
