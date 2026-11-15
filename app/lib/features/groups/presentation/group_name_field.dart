import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_fields.dart';

/// Limite do nome do grupo, contado sem os espaços das pontas
/// (docs/contratos-api.md, `create_group`).
const groupNameMax = 60;

/// Erro do nome do grupo, ou nulo (docs/ui/telas.md, 6.2). Conta como o
/// `char_length` do banco, por caractere, e não por unidade UTF-16.
String? validateGroupName(AppLocalizations l10n, String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return l10n.groupNameRequired;
  if (name.runes.length > groupNameMax) return l10n.groupNameTooLong;
  return null;
}

/// Campo "Nome do grupo" da criação e da edição.
class GroupNameField extends StatelessWidget {
  const GroupNameField({
    required this.controller,
    required this.enabled,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LabeledField(
      label: l10n.groupNameLabel,
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      validator: (value) => validateGroupName(l10n, value),
    );
  }
}
