import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/groups/domain/invite_code.dart';

/// Cenário U08 de docs/testes-referencia.md, seção 11.6: o código de convite
/// digitado (docs/ui/telas.md, 6.3).
void main() {
  test('U08: tira os espaços das pontas', () {
    expect(normalizeInviteCode(' VoleiQuinta1 '), 'VoleiQuinta1');
  });

  test('U08: tira os espaços do meio', () {
    expect(normalizeInviteCode('Volei Quinta1'), 'VoleiQuinta1');
  });

  test('U08: com 11 caracteres, é inválido', () {
    expect(normalizeInviteCode('VoleiQuinta'), isNull);
  });

  test('U08: com caractere que não é letra nem número, é inválido', () {
    expect(normalizeInviteCode('VoleiQuinta1!'), isNull);
  });

  test('U08: a caixa é mantida', () {
    expect(normalizeInviteCode('voleiquinta1'), 'voleiquinta1');
  });
}
