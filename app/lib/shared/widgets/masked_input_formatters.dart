import 'package:flutter/services.dart';

import '../../core/format/br_documents.dart';
import '../../core/format/phone.dart';

/// Máscara que reescreve o texto a partir dos dígitos, até [maxDigits].
class _DigitMaskFormatter extends TextInputFormatter {
  _DigitMaskFormatter(this.maxDigits, this.mask);

  final int maxDigits;
  final String Function(String digits) mask;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = digitsOnly(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final text = mask(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// `(86) 99999-1234`: DDD e número, com 10 ou 11 dígitos (telas.md, 5.8).
TextInputFormatter phoneInputFormatter() =>
    _DigitMaskFormatter(11, formatNationalPhone);

/// `000.000.000-00` (telas.md, 5.9).
TextInputFormatter cpfInputFormatter() => _DigitMaskFormatter(11, (d) {
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 3 || i == 6) b.write('.');
    if (i == 9) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
});

/// `00.000.000/0000-00` (telas.md, 5.9).
TextInputFormatter cnpjInputFormatter() => _DigitMaskFormatter(14, (d) {
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i == 2 || i == 5) b.write('.');
    if (i == 8) b.write('/');
    if (i == 12) b.write('-');
    b.write(d[i]);
  }
  return b.toString();
});
