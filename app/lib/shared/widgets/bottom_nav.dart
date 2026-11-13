import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Um destino da navegação inferior.
class NavDestinationData {
  const NavDestinationData({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Contador vermelho de Cobranças. Zero não mostra nada.
  final int badgeCount;
}

/// Navegação inferior (docs/ui/design-system.md, 7.6).
///
/// Altura mínima 76, fundo `surface`, cantos de cima 28. O item ativo é um
/// círculo de 56 em `primary`, com o ícone preenchido, que sobe acima da barra
/// com um anel de 5 na cor do fundo. A altura é mínima, não
/// fixa, para crescer com a fonte do sistema (RNF05).
class VoleiBottomNav extends StatelessWidget {
  const VoleiBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final List<NavDestinationData> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    data: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final NavDestinationData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    Widget icon = Icon(
      data.icon,
      size: 24,
      fill: selected ? 1 : 0,
      color: selected ? theme.colorScheme.onPrimary : color,
    );

    if (data.badgeCount > 0) {
      icon = Badge(
        label: Text(data.badgeCount.toString()),
        backgroundColor: VoleiColors.of(context).bad.dot,
        child: icon,
      );
    }

    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: selected
                    ? _RaisedCircle(
                        color: theme.colorScheme.primary,
                        ring: theme.scaffoldBackgroundColor,
                        child: icon,
                      )
                    : Center(child: icon),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Círculo do item ativo (design-system.md, 7.6): 56 em `primary`, com um anel
/// de 5 na cor do fundo, elevado acima da barra. Sobe só na pintura: a altura
/// da barra e a área de toque continuam as mesmas.
class _RaisedCircle extends StatelessWidget {
  const _RaisedCircle({
    required this.color,
    required this.ring,
    required this.child,
  });

  static const _ringWidth = 5.0;
  static const _lift = 18.0;

  final Color color;
  final Color ring;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      maxWidth: 56 + 2 * _ringWidth,
      maxHeight: 56 + 2 * _ringWidth,
      child: Transform.translate(
        offset: const Offset(0, -_lift),
        child: Container(
          width: 56 + 2 * _ringWidth,
          height: 56 + 2 * _ringWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: _ringWidth),
          ),
          child: child,
        ),
      ),
    );
  }
}
