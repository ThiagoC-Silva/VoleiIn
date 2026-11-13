import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';

/// Rótulo acima do campo, fora dele (design-system.md, 7.2).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Campo com o rótulo acima. O erro aparece abaixo, com ícone e texto: nunca
/// só pela cor (design-system.md, 7.2).
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.validator,
    this.forceErrorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.helperText,
    this.prefixText,
    this.onChanged,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.suffixIcon,
    this.focusNode,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  /// Erro vindo do servidor, mostrado como o erro de campo.
  final String? forceErrorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? helperText;
  final String? prefixText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          validator: validator,
          forceErrorText: forceErrorText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: autocorrect,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          obscureText: obscureText,
          // Erro com ícone, e não só com a cor (design-system.md, 7.2).
          errorBuilder: (context, errorText) => _AtFieldEdge(
            child: FieldErrorText(errorText, padding: EdgeInsets.zero),
          ),
          decoration: InputDecoration(
            // A ajuda e o erro começam na borda do campo, como o rótulo
            // acima dele (PNG da fatia 2), e não recuados como o texto.
            helper: helperText == null
                ? null
                : _AtFieldEdge(
                    child: Text(
                      helperText!,
                      maxLines: 3,
                      style:
                          theme.inputDecorationTheme.helperStyle ??
                          theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
            errorMaxLines: 3,
            // Prefixo fixo, visível mesmo com o campo vazio (telas.md, 5.8).
            // O `prefixText` do Flutter só aparece com foco ou com texto.
            prefixIcon: prefixText == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16),
                    child: Text(
                      prefixText!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Mensagem de erro de campo com o ícone, para os campos que não são
/// `TextFormField` (o campo de código).
class FieldErrorText extends StatelessWidget {
  const FieldErrorText(
    this.text, {
    this.padding = const EdgeInsets.only(top: 8),
    super.key,
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.error, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de senha com o botão de olho para mostrar e ocultar (telas.md, 4.1).
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.validator,
    this.forceErrorText,
    this.helperText,
    this.newPassword = false,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final String? forceErrorText;
  final String? helperText;

  /// Senha nova: o *autofill* sugere uma senha em vez de preencher a salva.
  final bool newPassword;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
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
    return LabeledField(
      label: widget.label,
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      validator: widget.validator,
      forceErrorText: widget.forceErrorText,
      helperText: widget.helperText,
      obscureText: !_visible,
      autocorrect: false,
      autofillHints: [
        widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      suffixIcon: IconButton(
        // Área de toque de 48 x 48 e rótulo para o TalkBack.
        iconSize: 24,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        tooltip: _visible ? l10n.authHidePassword : l10n.authShowPassword,
        icon: Icon(_visible ? Symbols.visibility_off : Symbols.visibility),
        onPressed: () => setState(() => _visible = !_visible),
      ),
    );
  }
}

/// Espera o campo ser reconstruído depois de a tela limpar um erro vindo do
/// servidor. O `forceErrorText` só sai do campo no quadro seguinte, e um
/// `validate()` antes disso ainda veria o erro antigo e barraria o envio.
Future<void> afterServerErrorCleared() => WidgetsBinding.instance.endOfFrame;

/// Desloca a ajuda e o erro do campo para a borda dele. O Flutter os põe em
/// `contentPadding.start` mais o `inputGap` (4) do `InputDecorator`.
class _AtFieldEdge extends StatelessWidget {
  const _AtFieldEdge({required this.child});

  static const _inputGap = 4.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding =
        Theme.of(context).inputDecorationTheme.contentPadding
            ?.resolve(Directionality.of(context)) ??
        EdgeInsets.zero;
    final shift = padding.left + _inputGap;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    return Transform.translate(
      offset: Offset(ltr ? -shift : shift, 0),
      child: child,
    );
  }
}
