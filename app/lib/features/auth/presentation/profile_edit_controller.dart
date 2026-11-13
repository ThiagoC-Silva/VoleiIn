import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/photo_picker.dart';
import '../data/profile_repository.dart';
import 'profile_providers.dart';
import 'submit_controller.dart';

/// O que a pessoa fez com a foto antes de salvar.
sealed class PhotoChange {
  const PhotoChange();
}

class PhotoKept extends PhotoChange {
  const PhotoKept();
}

class PhotoReplaced extends PhotoChange {
  const PhotoReplaced(this.photo);
  final PickedPhoto photo;
}

class PhotoRemoved extends PhotoChange {
  const PhotoRemoved();
}

/// Editar perfil (RF08 a RF10, RF12; docs/ui/telas.md, 5.8).
class ProfileEditController extends SubmitController {
  ProfileRepository get _profiles => ref.read(profileRepositoryProvider);

  /// Galeria ou câmera. Nulo se a pessoa desistiu; tipo recusado lança
  /// `AppException(photoInvalidType)`.
  Future<PickedPhoto?> pickPhoto(PhotoSource source) =>
      ref.read(photoPickerProvider).pick(source);

  /// Grava tudo, na ordem do documento: a foto nova, `profiles`,
  /// `profile_private` e, por fim, apaga a foto antiga, se ela foi trocada ou
  /// removida. A falha ao apagar é ignorada: o perfil já está salvo.
  Future<AppException?> save({
    required String name,
    required String? nickname,
    required String? phone,
    required bool phoneVisible,
    required String? currentPhotoPath,
    required PhotoChange photo,
  }) async {
    final error = await submit(() async {
      var photoPath = currentPhotoPath;
      if (photo case PhotoReplaced(:final photo)) {
        photoPath = await _profiles.uploadAvatar(
          bytes: photo.bytes,
          extension: photo.extension,
        );
      } else if (photo is PhotoRemoved) {
        photoPath = null;
      }
      await _profiles.updateProfile(
        name: name,
        nickname: nickname,
        photoPath: photoPath,
      );
      await _profiles.updateContact(phone: phone, phoneVisible: phoneVisible);
      if (currentPhotoPath != null && photo is! PhotoKept) {
        try {
          await _profiles.deleteAvatar(currentPhotoPath);
        } catch (_) {
          // O arquivo fica para a limpeza da fatia 6 (modelo-dados.md, 7).
        }
      }
    });
    if (error == null && ref.mounted) ref.invalidate(ownProfileProvider);
    return error;
  }
}

final profileEditControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileEditController, void>(
      ProfileEditController.new,
    );
