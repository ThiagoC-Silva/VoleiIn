import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_controller.dart';
import 'package:voleiin/features/auth/presentation/login_controller.dart';

/// Os formulários desabilitam os campos enquanto o controller está ocupado.
/// Um controller que nasce em carregamento desabilita a tela no primeiro
/// quadro e anula o autofocus (L08 e L11 no emulador, 13/11/2026).
void main() {
  test('o controller de formulário nasce pronto, sem carregar', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final login = container.listen(loginControllerProvider, (_, _) {});
    final confirm = container.listen(confirmEmailControllerProvider, (_, _) {});

    expect(login.read().isLoading, isFalse);
    expect(confirm.read().isLoading, isFalse);
  });
}
