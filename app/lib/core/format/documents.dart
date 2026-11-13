/// CPF e CNPJ: conferência e formato (docs/ui/telas.md, 5.9).
///
/// É a mesma regra das constraints do banco (`private.is_valid_cpf` e
/// `private.is_valid_cnpj`), que decidem de verdade. O app repete a conta só
/// para mostrar o erro no campo sem chamar o servidor.
library;

/// Só os dígitos do texto.
String digitsOnly(String text) => text.replaceAll(RegExp(r'[^0-9]'), '');

/// CNPJ como é gravado: sem pontuação e em maiúsculas. O CNPJ segue o formato
/// alfanumérico da Receita Federal (docs/modelo-dados.md, 4.1).
String normalizeCnpj(String text) =>
    text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

/// Os caracteres de CNPJ enquanto se digita, para a máscara: em maiúsculas,
/// letras e números nos 12 primeiros e só números nos 2 verificadores. O que
/// não cabe na posição é descartado, e o texto para em 14 caracteres.
String cnpjMaskCharacters(String text) {
  final out = StringBuffer();
  for (final char in text.toUpperCase().split('')) {
    if (out.length == 14) break;
    final allowed = out.length < 12 ? _cnpjBase : _digit;
    if (allowed.hasMatch(char)) out.write(char);
  }
  return out.toString();
}

final _digit = RegExp(r'^[0-9]$');
final _cnpjBase = RegExp(r'^[0-9A-Z]$');
final _cnpjFormat = RegExp(r'^[0-9A-Z]{12}[0-9]{2}$');

/// CPF com 11 dígitos e os dois dígitos verificadores certos. A sequência de
/// um dígito só (111.111.111-11) passa na conta, mas não é CPF.
bool isValidCpf(String text) {
  final d = _digits(text);
  if (d.length != 11 || _allSame(d)) return false;
  return _cpfDigit(d, 9) == d[9] && _cpfDigit(d, 10) == d[10];
}

/// CNPJ no formato alfanumérico da Receita: 12 caracteres, letras ou números,
/// e os 2 dígitos verificadores certos. Aceita pontuação e minúsculas, porque
/// confere o texto já normalizado. O CNPJ só com números é o caso particular
/// da mesma conta.
bool isValidCnpj(String text) {
  final cnpj = normalizeCnpj(text);
  if (!_cnpjFormat.hasMatch(cnpj)) return false;
  // Na conta, cada caractere vale o código ASCII menos 48: os números valem
  // eles mesmos, A vale 17 e Z vale 42.
  final d = cnpj.codeUnits.map((c) => c - 48).toList();
  if (_allSame(d)) return false;
  return _cnpjDigit(d, 12) == d[12] && _cnpjDigit(d, 13) == d[13];
}

/// `52998224725` → `529.982.247-25`. Parcial enquanto se digita.
String formatCpf(String text) => _mask(digitsOnly(text), '###.###.###-##');

/// `11222333000181` → `11.222.333/0001-81`; `12ABC34501DE35` →
/// `12.ABC.345/01DE-35`. Parcial enquanto se digita.
String formatCnpj(String text) =>
    _mask(normalizeCnpj(text), '##.###.###/####-##');

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
/// 2 a 9 da direita para a esquerda, sobre o valor de cada caractere.
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

/// Aplica a máscara (`#` é um caractere) até onde houver caracteres.
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
