import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Avatar de pessoa: foto ou iniciais sobre pastel (design-system.md, 3.4).
///
/// O pastel vem do `id` do perfil, para a mesma pessoa ter sempre a mesma cor.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.id,
    required this.name,
    required this.size,
    this.image,
    this.semanticLabel,
    super.key,
  });

  final String id;
  final String name;
  final double size;

  /// Foto já carregada (URL assinada ou arquivo escolhido).
  final ImageProvider? image;
  final String? semanticLabel;

  /// Iniciais do primeiro e do último nome, em maiúsculas.
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  /// Índice do pastel: hash estável do id, resto da divisão por 6.
  static int pastelIndex(String id, int count) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % count;
  }

  @override
  Widget build(BuildContext context) {
    final colors = VoleiColors.of(context);
    final theme = Theme.of(context);
    final pastel =
        colors.avatarPastels[pastelIndex(id, colors.avatarPastels.length)];
    return Semantics(
      label: semanticLabel ?? name,
      image: true,
      child: ExcludeSemantics(
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: pastel,
          foregroundImage: image,
          // Foto que não carrega (sem rede, URL vencida): ficam as iniciais.
          onForegroundImageError: image == null ? null : (_, _) {},
          child: Text(
            initialsOf(name),
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: size * 0.36,
              color: colors.onBlock,
            ),
          ),
        ),
      ),
    );
  }
}
