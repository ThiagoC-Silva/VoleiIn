import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/phone.dart';

/// Cenários U03 e U04 de docs/testes-referencia.md, seção 10.4. Só números do
/// Brasil, com DDD e 10 ou 11 dígitos (docs/modelo-dados.md, 4.1).
void main() {
  test('U03: telefone digitado para E.164', () {
    expect(phoneToE164('(86) 99999-1234'), '+5586999991234');
    expect(phoneToE164('(86) 3322-1234'), '+558633221234');
    expect(phoneToE164('(86) 9999-123'), isNull);
  });

  test('U04: E.164 para exibição', () {
    expect(formatPhoneE164('+5586999991234'), '(86) 99999-1234');
    expect(formatPhoneE164('+558633221234'), '(86) 3322-1234');
  });
}
