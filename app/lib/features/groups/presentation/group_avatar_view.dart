import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import 'groups_providers.dart';

/// Avatar quadrado do grupo com a foto do bucket privado, pela URL assinada.
/// Enquanto a URL carrega, ou se ela falha, as iniciais.
class GroupAvatarView extends ConsumerWidget {
  const GroupAvatarView({
    required this.id,
    required this.name,
    this.photoPath,
    this.imageUrl,
    this.imageBytes,
    this.size = 44,
    super.key,
  });

  final String id;
  final String name;
  final String? photoPath;

  /// URL já pronta (a da prévia do convite).
  final String? imageUrl;

  /// Foto escolhida e ainda não salva.
  final Uint8List? imageBytes;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    final url =
        imageUrl ??
        (path == null ? null : ref.watch(groupAvatarUrlProvider(path)).value);
    return GroupAvatar(
      id: id,
      name: name,
      semanticLabel: AppLocalizations.of(context).groupPhotoLabel(name),
      size: size,
      imageUrl: url,
      imageBytes: imageBytes,
    );
  }
}

/// Avatar redondo de uma pessoa do grupo, com a foto pela URL assinada.
class PersonAvatarView extends ConsumerWidget {
  const PersonAvatarView({
    required this.id,
    required this.name,
    this.photoPath,
    this.isYou = false,
    super.key,
  });

  final String id;
  final String name;
  final String? photoPath;
  final bool isYou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    final url = path == null
        ? null
        : ref.watch(groupAvatarUrlProvider(path)).value;
    return VoleiAvatar(id: id, name: name, isYou: isYou, imageUrl: url);
  }
}
