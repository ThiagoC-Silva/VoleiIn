import 'package:flutter/services.dart';

import 'documents.dart';
import 'phone.dart';

/// Máscaras dos campos (research R8): CPF, CNPJ e telefone. Cada uma aceita só
/// dígitos, corta no limite e reaplica o formato a cada tecla, com o cursor no
/// fim. As funções de formato são as mesmas da exibição (U04, U05).
class DigitMaskFormatter extends TextInputFormatter {
  const DigitMaskFormatter._(this._maxDigits, this._format);

  final int _maxDigits;
  final String Function(String digits) _format;

  static final cpf = DigitMaskFormatter._(11, formatCpf);
  static final cnpj = DigitMaskFormatter._(14, formatCnpj);

  /// Telefone sem o `+55`, que fica fixo como prefixo do campo.
  static final phone = DigitMaskFormatter._(11, formatPhoneDigits);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = digitsOnly(newValue.text);
    // Apagar um separador apaga também o dígito antes dele.
    // Só vale para um caractere apagado: trocar o texto inteiro pelos mesmos
    // dígitos sem os separadores não corta nada.
    if (oldValue.text.length - newValue.text.length == 1 &&
        digits == digitsOnly(oldValue.text) &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }
    if (digits.length > _maxDigits) digits = digits.substring(0, _maxDigits);
    final text = _format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
