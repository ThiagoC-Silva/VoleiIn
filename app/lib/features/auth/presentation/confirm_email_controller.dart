import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'auth_providers.dart';
import 'submit_controller.dart';

/// Confirmação do cadastro por código (RF02, ADR 0017; docs/ui/telas.md, 5.3).
class ConfirmEmailController extends SubmitController {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// O código cria a sessão, e o roteador segue para a conferência dos termos.
  Future<AppException?> confirm(String code) async {
    final draft = ref.read(accessDraftProvider);
    if (draft == null) return const AppException(ErrorCode.notAuthenticated);
    final error = await submit(
      () => _auth.confirmSignup(
        email: draft.email,
        code: code,
        password: draft.password,
      ),
    );
    if (error == null && ref.mounted) {
      ref.read(accessDraftProvider.notifier).clear();
    }
    return error;
  }

  Future<void> resend() async {
    final draft = ref.read(accessDraftProvider);
    if (draft == null) return;
    await _auth.resendSignupCode(draft.email);
  }
}

final confirmEmailControllerProvider =
    AsyncNotifierProvider.autoDispose<ConfirmEmailController, void>(
      ConfirmEmailController.new,
    );
