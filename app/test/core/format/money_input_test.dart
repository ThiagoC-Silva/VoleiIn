import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/core/format/money_input.dart';

/// Cenário U09 de docs/testes-referencia.md, seção 12.6: o campo de dinheiro
/// da criação do jogo (docs/ui/telas.md, 7.2). Os dígitos entram pela direita,
/// como nas maquininhas, e o valor vira centavos inteiros (RN04). O `R$` é o
/// prefixo fixo do campo, fora do texto.
void main() {
  const formatter = MoneyInputFormatter();

  /// Aplica as teclas, como o teclado numérico faz: cada dígito vai para o
  /// fim do texto, e `⌫` apaga o último caractere.
  String type(String keys, {String from = ''}) {
    var value = TextEditingValue(
      text: from,
      selection: TextSelection.collapsed(offset: from.length),
    );
    for (final key in keys.split('')) {
      final text = key == '⌫'
          ? value.text.substring(
              0,
              value.text.isEmpty ? 0 : value.text.length - 1,
            )
          : value.text + key;
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }
    return value.text;
  }

  String shown(String text) => 'R\$$nbsp$text';

  test('U09: digitar 1 mostra R\$ 0,01 e guarda 1', () {
    final text = type('1');
    expect(shown(text), 'R\$${nbsp}0,01');
    expect(parseMoneyInput(text), 1);
  });

  test('U09: digitar 1, 2, 0, 0, 0 mostra R\$ 120,00 e guarda 12000', () {
    final text = type('12000');
    expect(shown(text), 'R\$${nbsp}120,00');
    expect(parseMoneyInput(text), 12000);
  });

  test('U09: digitar 0 mostra R\$ 0,00 e guarda 0', () {
    final text = type('0');
    expect(shown(text), 'R\$${nbsp}0,00');
    expect(parseMoneyInput(text), 0);
  });

  test('U09: apagar tudo deixa o campo vazio', () {
    final text = type('12000⌫⌫⌫⌫⌫');
    expect(text, '');
    expect(parseMoneyInput(text), isNull);
  });

  test('U09: o milhar leva ponto, como no formatCents', () {
    final text = type('123456');
    expect(shown(text), formatCents(123456));
  });

  test('U09: o dígito além de 2147483647 é ignorado', () {
    final full = type('2147483647');
    expect(parseMoneyInput(full), 2147483647);
    expect(shown(full), 'R\$${nbsp}21.474.836,47');

    final more = type('1', from: full);
    expect(more, full);
    expect(parseMoneyInput(more), 2147483647);

    // 9999999999 passa do limite no décimo dígito.
    expect(parseMoneyInput(type('9999999999')), 999999999);
  });

  test('letras e símbolos colados não entram', () {
    expect(parseMoneyInput(type('1a2')), 12);
  });
}
