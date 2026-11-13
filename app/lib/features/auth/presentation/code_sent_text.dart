import 'package:flutter/material.dart';

/// Frase do ARB com um valor em negrito, como o e-mail em "Enviamos um código
/// de 6 dígitos para {email}." (confirmEmail.png, profileEmail-etapa1.png).
class BoldValueText extends StatelessWidget {
  const BoldValueText({
    required this.text,
    required this.value,
    this.style,
    this.textAlign,
    super.key,
  });

  /// Frase já preenchida pelo ARB.
  final String text;

  /// Trecho da frase que vai em negrito.
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    final index = value.isEmpty ? -1 : text.indexOf(value);
    if (index < 0) return Text(text, style: base, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(index + value.length)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
