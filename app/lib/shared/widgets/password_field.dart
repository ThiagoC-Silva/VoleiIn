import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';

/// Campo de senha com o olho de mostrar e ocultar (docs/ui/telas.md, 4.1).
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    this.enabled = true,
    this.newPassword = false,
    this.validator,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;

  /// Senha nova: muda o autofill para sugerir uma senha.
  final bool newPassword;
  final FormFieldValidator<String>? validator;

  /// Erro vindo do servidor, mostrado no campo.
  final String? errorText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: !_visible,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        errorText: widget.errorText,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          // Área de toque de 48 x 48 e rótulo para o TalkBack.
          iconSize: 24,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          tooltip: _visible ? l10n.authHidePassword : l10n.authShowPassword,
          icon: Icon(_visible ? Symbols.visibility_off : Symbols.visibility),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ),
    );
  }
}
