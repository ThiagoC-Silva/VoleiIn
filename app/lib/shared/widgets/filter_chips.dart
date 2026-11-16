import 'package:flutter/material.dart';

/// Chips de filtro (design-system.md, 7.5; games.png): o ativo com fundo
/// `onSurface` e texto navy, o inativo só com o contorno `surfaceHigh`.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            selected: i == selected,
            button: true,
            child: Material(
              color: i == selected
                  ? theme.colorScheme.onSurface
                  : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(
                  color: i == selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      labels[i],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: i == selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
