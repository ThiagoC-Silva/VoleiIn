import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'form_fields.dart';

/// Campo do código de 6 dígitos (docs/ui/telas.md, regras comuns da seção 5;
/// confirmEmail.png): seis casas em Bebas Neue sobre um campo só, com teclado
/// numérico e *autofill* do código de uso único. Ao completar o sexto dígito,
/// chama [onCompleted].
class CodeField extends StatefulWidget {
  const CodeField({
    required this.controller,
    this.onCompleted,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.removeListener(_changed);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _onChanged(String value) {
    if (value.length == CodeField.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final code = widget.controller.text;
    final hasError = widget.errorText != null;
    final current = code.length.clamp(0, CodeField.length - 1);
    final digitStyle = theme.textTheme.displaySmall?.copyWith(fontSize: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < CodeField.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasError
                                ? theme.colorScheme.error
                                : _focus.hasFocus && i == current
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHigh,
                            width: hasError || (_focus.hasFocus && i == current)
                                ? 2
                                : 1.5,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: digitStyle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // O campo de verdade, invisível, recebe o toque, o teclado, o
            // autofill e o TalkBack.
            Positioned.fill(
              child: Semantics(
                label: l10n.authCodeLabel,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: CodeField.length,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onChanged,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError) FieldErrorText(widget.errorText!),
      ],
    );
  }
}
