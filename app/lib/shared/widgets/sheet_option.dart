import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import 'confirm_sheet.dart';
import 'icon_square.dart';

/// Opção de uma sheet: quadrado de ícone e o texto, com 64 de altura mínima
/// (profileEdit-foto.png, groupMembers-acoes.png). [color] é o tom destrutivo.
class SheetOption extends StatelessWidget {
  const SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Linha de apoio, abaixo do rótulo (gameSplit-isentar.png).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            IconSquare(icon: icon, foreground: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (subtitle case final note?)
                    Text(
                      note,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opções empilhadas, com divisor recuado entre elas.
class SheetOptions extends StatelessWidget {
  const SheetOptions({required this.options, super.key});

  final List<SheetOption> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 56),
          options[i],
        ],
      ],
    );
  }
}

/// O que a pessoa escolheu na sheet da foto.
enum PhotoAction { gallery, camera, remove }

/// Sheet da foto, sem título (docs/ui/telas.md, 5.8; decisão de 12/11/2026),
/// a mesma do perfil e do grupo (6.2 e 6.8). Remover foto fica em tom
/// destrutivo e sem confirmação: só vale no Salvar.
Future<PhotoAction?> showPhotoSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  final l10n = AppLocalizations.of(context);
  return showVoleiSheet<PhotoAction>(context, (context) {
    final error = Theme.of(context).colorScheme.error;
    return SheetOptions(
      options: [
        SheetOption(
          icon: Symbols.photo_library,
          label: l10n.profilePhotoGallery,
          onTap: () => Navigator.of(context).pop(PhotoAction.gallery),
        ),
        SheetOption(
          icon: Symbols.photo_camera,
          label: l10n.profilePhotoCamera,
          onTap: () => Navigator.of(context).pop(PhotoAction.camera),
        ),
        if (canRemove)
          SheetOption(
            icon: Symbols.delete,
            label: l10n.profilePhotoRemove,
            color: error,
            onTap: () => Navigator.of(context).pop(PhotoAction.remove),
          ),
      ],
    );
  });
}
