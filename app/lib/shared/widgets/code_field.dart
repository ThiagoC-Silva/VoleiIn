import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo do código de 6 dígitos (docs/ui/telas.md, 5, "Campo de código").
///
/// Seis casas desenhadas sobre um campo de texto único, que recebe o teclado
/// numérico e o autofill de código de uso único. Ao completar o sexto dígito,
/// chama [onCompleted] sozinho, sem precisar tocar no botão.
class CodeField extends StatefulWidget {
  const CodeField({
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.errorText,
    this.semanticLabel,
    super.key,
  });

  static const length = 6;

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final String? errorText;

  /// Rótulo do campo para o TalkBack ("Código").
  final String? semanticLabel;

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _onChanged() {
    setState(() {});
    final code = widget.controller.text;
    if (code.length == CodeField.length) widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = widget.controller.text;
    final hasError = widget.errorText != null;
    final digitStyle = theme.textTheme.displaySmall;

    Widget box(int index) {
      final focused =
          _focus.hasFocus &&
          (index == code.length ||
              (index == CodeField.length - 1 &&
                  code.length == CodeField.length));
      final color = hasError
          ? theme.colorScheme.error
          : focused
          ? theme.colorScheme.primary
          : theme.colorScheme.outline;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
          constraints: const BoxConstraints(minHeight: 60),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color,
              width: focused || hasError ? 2 : 1.5,
            ),
          ),
          child: Text(
            index < code.length ? code[index] : '',
            style: digitStyle,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Row(children: List.generate(CodeField.length, box)),
            // O campo real fica por cima, transparente: recebe toque, teclado,
            // colagem e autofill.
            Positioned.fill(
              child: Semantics(
                label: widget.semanticLabel,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(CodeField.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
