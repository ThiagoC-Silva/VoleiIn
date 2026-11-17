import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/phone.dart';

/// Cenários U03 e U04 de docs/testes-referencia.md, seção 10.4, e U12 da
/// seção 12.6 (links do perfil de outra pessoa, fatia 4).
void main() {
  group('U03: telefone digitado para E.164', () {
    test('celular com 11 dígitos', () {
      expect(phoneToE164('(86) 99999-1234'), '+5586999991234');
    });

    test('fixo com 10 dígitos', () {
      expect(phoneToE164('(86) 3322-1234'), '+558633221234');
    });

    test('número incompleto é inválido', () {
      expect(phoneToE164('(86) 9999-123'), isNull);
    });
  });

  group('U04: E.164 para exibição', () {
    test('celular', () {
      expect(formatPhone('+5586999991234'), '(86) 99999-1234');
    });

    test('fixo', () {
      expect(formatPhone('+558633221234'), '(86) 3322-1234');
    });
  });

  group('U12: telefone no perfil de outra pessoa', () {
    test('celular: formato, discador e WhatsApp', () {
      expect(formatPhone('+5586999998888'), '(86) 99999-8888');
      expect(phoneCallUri('+5586999998888'), Uri.parse('tel:+5586999998888'));
      expect(
        phoneWhatsappUri('+5586999998888'),
        Uri.parse('https://wa.me/5586999998888'),
      );
    });

    test('fixo', () {
      expect(formatPhone('+558633224455'), '(86) 3322-4455');
    });
  });
}
