import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/domain/auth_access.dart';

/// Cenário U07 de docs/testes-referencia.md, seção 10.4:
/// quem tem acesso por e-mail e senha (docs/ui/telas.md, 5.7).
void main() {
  test('U07: só a identidade email', () {
    expect(hasEmailAccess(['email']), isTrue);
  });

  test('U07: só a identidade google', () {
    expect(hasEmailAccess(['google']), isFalse);
  });

  test('U07: as duas formas de acesso (RF108)', () {
    expect(hasEmailAccess(['email', 'google']), isTrue);
  });
}
