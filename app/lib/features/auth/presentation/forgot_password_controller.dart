import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';
import 'submit_controller.dart';

/// Etapas da recuperação de senha, sem trocar de rota (docs/ui/telas.md, 5.4).
enum RecoveryStep {
  /// O e-mail.
  email,

  /// O código e a senha nova.
  code,

  /// O código valeu e criou a sessão, mas a senha nova foi recusada: só o
  /// campo de senha, e o novo toque chama só o `updateUser`.
  password,
}

/// Recuperação de senha com código (RF06, ADR 0017).
class ForgotPasswordController extends SubmitController {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  PasswordRecoveryNotifier get _recovery =>
      ref.read(passwordRecoveryInProgressProvider.notifier);

  /// O Auth responde igual para e-mail com e sem conta.
  Future<AppException?> sendCode(String email) =>
      submit(() => _auth.sendPasswordRecovery(email.trim()));

  Future<void> resend(String email) => _auth.sendPasswordRecovery(email.trim());

  /// Confere o código (que cria a sessão) e grava a senha nova. Devolve a
  /// etapa em que a tela fica e o erro, se houver.
  Future<(RecoveryStep, AppException?)> savePassword({
    required String email,
    required String code,
    required String password,
  }) async {
    // A marca vem antes do código: a sessão nasce dentro do verifyOTP, e o
    // roteador não pode tirar a pessoa daqui antes da senha (research R2).
    _recovery.start();
    final codeError = await submit(
      () => _auth.verifyRecoveryCode(email: email.trim(), code: code),
    );
    if (codeError != null) {
      _recovery.finish();
      return (RecoveryStep.code, codeError);
    }
    return updatePassword(password);
  }

  /// Só a senha, depois de o código ter valido.
  Future<(RecoveryStep, AppException?)> updatePassword(String password) async {
    final error = await submit(() => _auth.updatePassword(password));
    if (error != null) return (RecoveryStep.password, error);
    return (RecoveryStep.password, null);
  }

  /// A senha foi gravada, ou a pessoa desistiu depois do código: o roteador
  /// volta a decidir (e a pessoa segue logada).
  void finish() => _recovery.finish();
}

final forgotPasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ForgotPasswordController, void>(
      ForgotPasswordController.new,
    );
