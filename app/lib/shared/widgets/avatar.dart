import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';

/// Avatar redondo (design-system.md, 3.4): a foto ou as iniciais em
/// Montserrat 800 sobre um pastel escolhido pelo `id`, sempre o mesmo para a
/// mesma pessoa, ou sobre o amarelo quando é a própria pessoa logada. Sem a
/// foto (falha ao carregar, por exemplo), as iniciais.
class VoleiAvatar extends StatelessWidget {
  const VoleiAvatar({
    required this.id,
    required this.name,
    this.size = 44,
    this.imageUrl,
    this.imageBytes,
    this.isYou = false,
    super.key,
  });

  final String id;

  /// O nome exibido: dá as iniciais e o rótulo do TalkBack.
  final String name;
  final double size;
  final String? imageUrl;

  /// Foto escolhida e ainda não salva.
  final Uint8List? imageBytes;

  /// Se é a própria pessoa logada: "você" usa sempre o amarelo
  /// (design-system.md, 3.4).
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: _photoOr(
            _Initials(id: id, name: name, size: size, isYou: isYou),
            size: size,
            imageUrl: imageUrl,
            imageBytes: imageBytes,
          ),
        ),
      ),
    );
  }
}

/// Avatar do grupo (design-system.md, 3.4): a mesma regra da pessoa, num
/// quadrado de cantos arredondados (raio = lado ÷ 3,4). Sem nome (a criação,
/// antes de digitar), o ícone `groups` no lugar das iniciais.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    required this.id,
    required this.name,
    required this.semanticLabel,
    this.size = 44,
    this.imageUrl,
    this.imageBytes,
    super.key,
  });

  /// O `id` do grupo, que escolhe o pastel. Na criação, antes de existir,
  /// qualquer texto estável.
  final String id;
  final String name;

  /// "Foto do grupo {name}" (`groupPhotoLabel`), para o TalkBack.
  final String semanticLabel;
  final double size;
  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 3.4),
        child: SizedBox(
          width: size,
          height: size,
          child: _photoOr(
            _Initials(id: id, name: name, size: size, isYou: false),
            size: size,
            imageUrl: imageUrl,
            imageBytes: imageBytes,
          ),
        ),
      ),
    );
  }
}

/// A foto escolhida, a foto salva ou, sem nenhuma (ou na falha ao carregar),
/// o [fallback].
Widget _photoOr(
  Widget fallback, {
  required double size,
  String? imageUrl,
  Uint8List? imageBytes,
}) {
  if (imageBytes != null) {
    return Image.memory(
      imageBytes,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  if (imageUrl != null) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  return fallback;
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.id,
    required this.name,
    required this.size,
    required this.isYou,
  });

  final String id;
  final String name;
  final double size;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final colors = VoleiColors.of(context);
    final pastel = isYou
        ? Theme.of(context).colorScheme.primary
        : colors.avatarPastels[_hash(id) % colors.avatarPastels.length];
    final initials = initialsOf(name);
    return ExcludeSemantics(
      child: Container(
        color: pastel,
        alignment: Alignment.center,
        child: initials.isEmpty
            ? Icon(Symbols.groups, size: size * 0.42, color: colors.onBlock)
            : Text(
                initials,
                // As iniciais acompanham o círculo, não a fonte do sistema.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.36,
                  color: colors.onBlock,
                ),
              ),
      ),
    );
  }

  /// Hash estável entre execuções (o `hashCode` do Dart não garante isso).
  static int _hash(String text) =>
      text.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);
}

/// Até duas iniciais: a primeira e a última palavra do nome.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  final first = words.first.characters.first;
  if (words.length == 1) return first.toUpperCase();
  return (first + words.last.characters.first).toUpperCase();
}
