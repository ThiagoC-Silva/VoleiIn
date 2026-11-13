/// CPF e CNPJ: conferência e formato (docs/ui/telas.md, 5.9).
///
/// É a mesma regra das constraints do banco (`private.is_valid_cpf` e
/// `private.is_valid_cnpj`), que decidem de verdade. O app repete a conta só
/// para mostrar o erro no campo sem chamar o servidor.
library;

/// Só os dígitos do texto.
String digitsOnly(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

/// CPF com 11 dígitos e os dois dígitos verificadores certos. A sequência de
/// um dígito só (111.111.111-11) passa na conta, mas não é CPF.
bool isValidCpf(String text) {
  final d = _digits(text);
  if (d.length != 11 || _allSame(d)) return false;
  return _cpfDigit(d, 9) == d[9] && _cpfDigit(d, 10) == d[10];
}

/// CNPJ com 14 dígitos e os dois dígitos verificadores certos.
bool isValidCnpj(String text) {
  final d = _digits(text);
  if (d.length != 14 || _allSame(d)) return false;
  return _cnpjDigit(d, 12) == d[12] && _cnpjDigit(d, 13) == d[13];
}

/// `52998224725` → `529.982.247-25`. Parcial enquanto se digita.
String formatCpf(String text) => _mask(digitsOnly(text), '###.###.###-##');

/// `11222333000181` → `11.222.333/0001-81`. Parcial enquanto se digita.
String formatCnpj(String text) => _mask(digitsOnly(text), '##.###.###/####-##');

List<int> _digits(String text) =>
    digitsOnly(text).split('').map(int.parse).toList();

bool _allSame(List<int> d) => d.every((x) => x == d.first);

/// Dígito verificador do CPF na posição [length] (9 ou 10), pelos pesos
/// decrescentes a partir de `length + 1`.
int _cpfDigit(List<int> d, int length) {
  var sum = 0;
  for (var i = 0; i < length; i++) {
    sum += d[i] * (length + 1 - i);
  }
  final rest = sum % 11;
  return rest < 2 ? 0 : 11 - rest;
}

/// Dígito verificador do CNPJ na posição [length] (12 ou 13), com os pesos de
/// 2 a 9 da direita para a esquerda.
int _cnpjDigit(List<int> d, int length) {
  var sum = 0;
  var weight = 2;
  for (var i = length - 1; i >= 0; i--) {
    sum += d[i] * weight;
    weight = weight == 9 ? 2 : weight + 1;
  }
  final rest = sum % 11;
  return rest < 2 ? 0 : 11 - rest;
}

/// Aplica a máscara (`#` é um dígito) até onde houver dígitos.
String _mask(String digits, String pattern) {
  final out = StringBuffer();
  var i = 0;
  for (final char in pattern.split('')) {
    if (i >= digits.length) break;
    if (char == '#') {
      out.write(digits[i++]);
    } else {
      out.write(char);
    }
  }
  return out.toString();
}
