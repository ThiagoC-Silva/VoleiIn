import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/format/image_type.dart';

enum PhotoSource { gallery, camera }

/// Foto escolhida, já redimensionada, com o tipo conferido pelos bytes.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.type});

  final Uint8List bytes;
  final ImageType type;
}

/// Escolha da foto de perfil, atrás de uma interface para os testes.
abstract interface class PhotoPicker {
  /// Nulo se a pessoa desistiu. Tipo fora de JPEG, PNG e WebP vira
  /// `photoInvalidType` (docs/ui/telas.md, 5.8).
  Future<PickedPhoto?> pick(PhotoSource source);
}

/// `image_picker`, com no máximo 1024 px no maior lado (RN106).
class ImagePickerPhotoPicker implements PhotoPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final type = ImageType.detect(bytes);
    if (type == null) throw const AppException(ErrorCode.photoInvalidType);
    return PickedPhoto(bytes: bytes, type: type);
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
