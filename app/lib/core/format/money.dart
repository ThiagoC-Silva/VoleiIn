/// Dinheiro em centavos inteiros (RN04). Nenhuma conta usa ponto flutuante,
/// nem intermediária (docs/arquitetura-app.md, seção 8).
library;

/// Espaço sem quebra entre `R$` e o número (docs/copy.md, seção 3): impede que
/// o símbolo fique numa linha e o valor em outra.
const String nbsp = '\u00A0';

/// `2084` vira `R$ 20,84`; `123456` vira `R$ 1.234,56`.
///
/// O formato de valor negativo é decidido na fatia 5 (cenário R04 de
/// docs/testes-referencia.md). Até lá, o sinal vai antes do `R$`.
String formatCents(int cents) {
  assert(cents >= 0, 'valor negativo: formato decidido na fatia 5');

  final sign = cents < 0 ? '-' : '';
  final absolute = cents.abs();
  final reais = absolute ~/ 100;
  final centavos = absolute % 100;
  final decimals = centavos.toString().padLeft(2, '0');

  return '${sign}R\$$nbsp${_groupThousands(reais)},$decimals';
}

/// `1234567` vira `1.234.567`.
String _groupThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
