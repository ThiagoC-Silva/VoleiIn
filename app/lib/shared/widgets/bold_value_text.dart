import 'package:flutter/material.dart';

/// Frase do catálogo com um valor em negrito, como o e-mail em "Enviamos um
/// código de 6 dígitos para {email}." (confirmEmail.png).
class BoldValueText extends StatelessWidget {
  const BoldValueText({
    required this.message,
    required this.value,
    this.style,
    super.key,
  });

  /// A frase já formatada, com o valor dentro.
  final String message;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    final start = message.indexOf(value);
    if (start < 0) return Text(message, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: message.substring(0, start)),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: message.substring(start + value.length)),
        ],
      ),
      style: base,
    );
  }
}
