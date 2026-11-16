import 'package:flutter/services.dart';

/// Maior valor de um `integer` do Postgres, o teto dos centavos (RN04).
const int maxCents = 2147483647;

/// Campo de dinheiro (docs/ui/telas.md, 7.2; U09): os dígitos entram pela
/// direita, como nas maquininhas. Digitar `1`, `2`, `0`, `0`, `0` mostra
/// `120,00`, e o `R$` é o prefixo fixo do campo. Um dígito que passaria de
/// [maxCents] é ignorado. Nenhuma conta usa ponto flutuante.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final significant = digits.replaceFirst(RegExp(r'^0+'), '');
    final String text;
    if (significant.isEmpty) {
      // Apagar o último dígito que vale esvazia o campo; digitar um zero
      // mostra 0,00.
      final deleting = newValue.text.length < oldValue.text.length;
      text = digits.isEmpty || deleting ? '' : formatCentsInput(0);
    } else {
      // Mais de 10 dígitos sempre passa do teto.
      final cents = significant.length > 10 ? null : int.parse(significant);
      if (cents == null || cents > maxCents) return oldValue;
      text = formatCentsInput(cents);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// `12000` vira `120,00`; `123456` vira `1.234,56`. O mesmo formato do
/// `formatCents`, sem o `R$`, que é o prefixo do campo.
String formatCentsInput(int cents) {
  final reais = (cents ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
    buffer.write(reais[i]);
  }
  return '$buffer,${(cents % 100).toString().padLeft(2, '0')}';
}

/// Os centavos do texto do campo, ou nulo com o campo vazio.
int? parseMoneyInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}
