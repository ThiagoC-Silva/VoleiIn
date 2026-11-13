import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';
import 'submit_controller.dart';

/// Cadastro com nome, e-mail e senha (RF01; docs/ui/telas.md, 5.2).
class SignupController extends SubmitController {
  /// No sucesso, guarda o cadastro em memória para a `/confirm-email`.
  Future<AppException?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final draft = (name: name.trim(), email: email.trim(), password: password);
    final error = await submit(
      () => ref
          .read(authRepositoryProvider)
          .signUp(
            name: draft.name,
            email: draft.email,
            password: draft.password,
          ),
    );
    if (error == null) {
      ref
          .read(accessDraftProvider.notifier)
          .save(name: draft.name, email: draft.email, password: draft.password);
    }
    return error;
  }
}

final signupControllerProvider =
    AsyncNotifierProvider.autoDispose<SignupController, void>(
      SignupController.new,
    );
