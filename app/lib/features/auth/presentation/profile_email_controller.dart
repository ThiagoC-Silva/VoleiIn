import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import 'profile_providers.dart';
import 'submit_controller.dart';

/// Trocar e-mail com código enviado ao endereço novo (RF106, ADR 0017;
/// docs/ui/telas.md, 5.10).
class ProfileEmailController extends SubmitController {
  AuthRepository get _auth => ref.read(authRepositoryProvider);

  Future<AppException?> sendCode(String newEmail) =>
      submit(() => _auth.requestEmailChange(newEmail));

  Future<void> resend(String newEmail) => _auth.requestEmailChange(newEmail);

  /// No sucesso, o perfil relê e mostra o e-mail novo.
  Future<AppException?> confirm({
    required String newEmail,
    required String code,
  }) async {
    final error = await submit(
      () => _auth.confirmEmailChange(newEmail: newEmail, code: code),
    );
    if (error == null && ref.mounted) ref.invalidate(ownProfileProvider);
    return error;
  }
}

final profileEmailControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileEmailController, void>(
      ProfileEmailController.new,
    );
