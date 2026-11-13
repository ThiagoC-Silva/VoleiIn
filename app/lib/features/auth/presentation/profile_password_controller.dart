import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'submit_controller.dart';

/// Em que campo fica o erro da troca de senha.
enum PasswordField { current, next }

/// Trocar senha informando a atual (RF107; docs/ui/telas.md, 5.11).
class ProfilePasswordController extends SubmitController {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// Confere a atual e, se ela vale, grava a nova. Devolve o erro e o campo
  /// a que ele pertence.
  Future<(PasswordField, AppException)?> change({
    required String current,
    required String next,
  }) async {
    var step = PasswordField.current;
    final error = await submit(() async {
      await _auth.verifyCurrentPassword(current);
      step = PasswordField.next;
      await _auth.updatePassword(next);
    });
    return error == null ? null : (step, error);
  }
}

final profilePasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfilePasswordController, void>(
      ProfilePasswordController.new,
    );
