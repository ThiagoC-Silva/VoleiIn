/// CPF e CNPJ: dígitos, validação e máscara (docs/ui/telas.md, 5.9).
///
/// A mesma regra está na constraint do banco (`private.is_valid_cpf` e
/// `private.is_valid_cnpj`, docs/modelo-dados.md, 4.1), que decide de verdade.
/// Aqui ela só serve para o aviso no campo, sem chamar o servidor.
library;

/// Só os dígitos de um texto digitado com ou sem máscara.
String digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

List<int> _digits(String value) =>
    value.codeUnits.map((unit) => unit - 0x30).toList(growable: false);

bool _allSame(String value) => value.split('').toSet().length == 1;

/// CPF com 11 dígitos, verificadores corretos e sem dígito repetido.
bool isValidCpf(String input) {
  final value = digitsOnly(input);
  if (value.length != 11 || _allSame(value)) return false;
  final d = _digits(value);

  int check(int length) {
    var sum = 0;
    for (var i = 0; i < length; i++) {
      sum += d[i] * (length + 1 - i);
    }
    return (sum * 10) % 11 % 10;
  }

  return check(9) == d[9] && check(10) == d[10];
}

/// CNPJ com 14 dígitos, verificadores corretos e sem dígito repetido.
bool isValidCnpj(String input) {
  final value = digitsOnly(input);
  if (value.length != 14 || _allSame(value)) return false;
  final d = _digits(value);
  const weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int check(List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += d[i] * weights[i];
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  return check(weights1) == d[12] && check(weights2) == d[13];
}

/// `52998224725` → `529.982.247-25`.
String formatCpf(String digits) {
  final d = digitsOnly(digits);
  if (d.length != 11) return digits;
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-'
      '${d.substring(9)}';
}

/// `11222333000181` → `11.222.333/0001-81`.
String formatCnpj(String digits) {
  final d = digitsOnly(digits);
  if (d.length != 14) return digits;
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
      '${d.substring(8, 12)}-${d.substring(12)}';
}
