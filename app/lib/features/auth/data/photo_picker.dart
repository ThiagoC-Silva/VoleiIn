import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/error_code.dart';

enum PhotoSource { gallery, camera }

/// A foto escolhida, já redimensionada.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.extension});

  final Uint8List bytes;

  /// `jpg`, `png` ou `webp`.
  final String extension;
}

/// Escolha da foto de perfil, trocável por dublê nos testes.
class PhotoPicker {
  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Lado maior da foto (RN106).
  static const maxSide = 1024.0;

  static const _extensions = {
    'jpg': 'jpg',
    'jpeg': 'jpg',
    'png': 'png',
    'webp': 'webp',
  };

  /// Nulo se a pessoa desistiu. Tipo fora de JPEG, PNG ou WebP lança
  /// `AppException(photoInvalidType)` (docs/ui/telas.md, 5.8). O tipo vem da
  /// extensão do arquivo (research R7).
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final dot = file.name.lastIndexOf('.');
    final raw = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    final extension = _extensions[raw];
    if (extension == null) {
      throw const AppException(ErrorCode.photoInvalidType);
    }
    return PickedPhoto(bytes: await file.readAsBytes(), extension: extension);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => PhotoPicker());
