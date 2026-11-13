import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/profile_repository.dart';
import '../domain/pix_key.dart';
import 'profile_providers.dart';
import 'submit_controller.dart';

/// Chave Pix (RF11, RF12, RN105; docs/ui/telas.md, 5.9).
class ProfilePixController extends SubmitController {
  ProfileRepository get _profiles => ref.read(profileRepositoryProvider);

  /// Trocar a chave é sempre permitido (RN105). A chave já vem conferida e
  /// normalizada pela tela; o banco confere de novo.
  Future<AppException?> save(PixKeyType type, String typed) => _write(
    () => _profiles.updatePixKey(type: type, key: normalizePixKey(type, typed)),
  );

  /// A *trigger* da RN105 recusa com `PIX_KEY_IN_USE`.
  Future<AppException?> remove() =>
      _write(() => _profiles.updatePixKey(type: null, key: null));

  Future<AppException?> _write(Future<void> Function() action) async {
    final error = await submit(action);
    if (error == null && ref.mounted) ref.invalidate(ownProfileProvider);
    return error;
  }
}

final profilePixControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfilePixController, void>(
      ProfilePixController.new,
    );
