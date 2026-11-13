import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';
import 'submit_controller.dart';

/// Ações do login (docs/ui/telas.md, 4.1 e 5.1). O redirecionamento depois de
/// entrar é do roteador.
class LoginController extends SubmitController {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Devolve `true` quando entrou.
  Future<bool> signIn({required String email, required String password}) async {
    final error = await submit(
      () => _auth.signInWithPassword(email: email.trim(), password: password),
    );
    if (error == null) ref.read(accessDraftProvider.notifier).clear();
    return error == null;
  }

  /// Fechar o seletor não é erro: devolve nulo e não mostra nada.
  Future<AppException?> signInWithGoogle() async {
    var signedIn = false;
    final error = await submit(() async {
      signedIn = await _auth.signInWithGoogle();
    });
    if (signedIn) ref.read(accessDraftProvider.notifier).clear();
    return error;
  }

  /// A ação Confirmar do e-mail não confirmado: guarda o e-mail e a senha em
  /// memória e pede um código novo.
  Future<AppException?> resendConfirmation({
    required String email,
    required String password,
  }) {
    ref
        .read(accessDraftProvider.notifier)
        .save(email: email.trim(), password: password);
    return submit(() => _auth.resendSignupCode(email.trim()));
  }

  /// Guarda o e-mail digitado para a recuperação de senha.
  void rememberEmail(String email) =>
      ref.read(accessDraftProvider.notifier).save(email: email.trim());
}

final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
      LoginController.new,
    );

/// Se o erro pede a ação Confirmar no `SnackBar`.
bool isEmailNotConfirmed(Object? error) =>
    error is AppException && error.code == ErrorCode.authEmailNotConfirmed;
