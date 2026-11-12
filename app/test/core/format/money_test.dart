import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/money.dart';

/// Cenários D01 a D08 de docs/testes-referencia.md, seção 9.3.
/// O espaço depois de `R$` é o espaço sem quebra (U+00A0).
void main() {
  group('formatCents', () {
    test('D01: 2084 vira R\$ 20,84', () {
      expect(formatCents(2084), 'R\$${nbsp}20,84');
    });

    test('D02: 22924 vira R\$ 229,24', () {
      expect(formatCents(22924), 'R\$${nbsp}229,24');
    });

    test('D03: 123456 vira R\$ 1.234,56', () {
      expect(formatCents(123456), 'R\$${nbsp}1.234,56');
    });

    test('D04: 0 vira R\$ 0,00', () {
      expect(formatCents(0), 'R\$${nbsp}0,00');
    });

    test('D05: 5 vira R\$ 0,05', () {
      expect(formatCents(5), 'R\$${nbsp}0,05');
    });

    test('D06: 100 vira R\$ 1,00', () {
      expect(formatCents(100), 'R\$${nbsp}1,00');
    });

    test('D07: 100000000 vira R\$ 1.000.000,00', () {
      expect(formatCents(100000000), 'R\$${nbsp}1.000.000,00');
    });

    test('D08: 2147483647, o maior integer, vira R\$ 21.474.836,47', () {
      expect(formatCents(2147483647), 'R\$${nbsp}21.474.836,47');
    });

    test('o espaço depois de R\$ não quebra linha', () {
      expect(nbsp, ' ');
      expect(formatCents(100).contains(' '), isFalse);
    });
  });
}
