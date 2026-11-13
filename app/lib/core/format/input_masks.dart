import 'package:flutter/services.dart';

import 'documents.dart';
import 'phone.dart';

/// Máscaras dos campos (research R8): CPF, CNPJ e telefone. Cada uma aceita só
/// os caracteres do tipo, corta no limite e reaplica o formato a cada tecla,
/// com o cursor no fim. As funções de formato são as mesmas da exibição (U04,
/// U05). CPF e telefone aceitam só dígitos; o CNPJ, no formato alfanumérico da
/// Receita, aceita letras nos 12 primeiros caracteres, em maiúsculas.
class DigitMaskFormatter extends TextInputFormatter {
  const DigitMaskFormatter._(this._maxDigits, this._format, this._clean);

  final int _maxDigits;
  final String Function(String chars) _format;
  final String Function(String text) _clean;

  static final cpf = DigitMaskFormatter._(11, formatCpf, digitsOnly);
  static final cnpj = DigitMaskFormatter._(14, formatCnpj, cnpjMaskCharacters);

  /// Telefone sem o `+55`, que fica fixo como prefixo do campo.
  static final phone = DigitMaskFormatter._(11, formatPhoneDigits, digitsOnly);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _clean(newValue.text);
    // Apagar um separador apaga também o dígito antes dele.
    // Só vale para um caractere apagado: trocar o texto inteiro pelos mesmos
    // dígitos sem os separadores não corta nada.
    if (oldValue.text.length - newValue.text.length == 1 &&
        digits == _clean(oldValue.text) &&
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
