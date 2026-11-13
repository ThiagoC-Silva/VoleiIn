import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/input_masks.dart';

TextEditingValue _value(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

String _apply(String old, String typed) =>
    DigitMaskFormatter.cpf.formatEditUpdate(_value(old), _value(typed)).text;

/// Máscaras dos campos (research R8).
void main() {
  test('formata os dígitos digitados', () {
    expect(_apply('', '52998224725'), '529.982.247-25');
  });

  test('apagar um separador apaga também o dígito antes dele', () {
    expect(_apply('529.982.', '529.982'), '529.98');
  });

  test('trocar o texto inteiro pelos mesmos dígitos não corta nenhum', () {
    // Colar a chave sem pontos sobre ela mesma formatada.
    expect(_apply('529.982.247-25', '52998224725'), '529.982.247-25');
  });

  test('corta no limite de dígitos do tipo', () {
    expect(_apply('', '529982247251234'), '529.982.247-25');
  });
}
