import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/features/games/presentation/split_text.dart';

import '../../../helpers/test_app.dart';

/// Cenário U13 de docs/testes-referencia.md, seção 13: o valor por conta do
/// recebedor, que pode ser negativo (R04; docs/ui/telas.md, seção 8).
void main() {
  test('U13: 2.076 vira R\$ 20,76', () {
    expect(receiverCoveredText(l10nPt, 2076, 'Ana'), 'R\$${nbsp}20,76');
  });

  test('U13: 0 vira R\$ 0,00', () {
    expect(receiverCoveredText(l10nPt, 0, 'Ana'), 'R\$${nbsp}0,00');
  });

  test('U13: −8 vira a frase splitReceiverExtra, sem sinal', () {
    expect(
      receiverCoveredText(l10nPt, -8, 'Ana'),
      'Ana recebe R\$${nbsp}0,08 a mais que o total, pelo arredondamento.',
    );
  });
}
