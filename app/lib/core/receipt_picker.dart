import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Um arquivo escolhido, ainda sem conferir tipo nem tamanho.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  /// O nome com a extensão, de onde sai o tipo.
  final String name;
  final Uint8List bytes;
}

/// Escolha do comprovante (docs/ui/telas.md, 9.3; arquitetura-app.md, seção
/// 3), trocável por dublê nos testes. Só escolhe: quem confere o tipo e o
/// tamanho é a sheet, com `ReceiptFile.fromPicked`.
class ReceiptPicker {
  ReceiptPicker([ImagePicker? images]) : _images = images ?? ImagePicker();

  final ImagePicker _images;

  /// Lado maior da imagem: o limite da Claude API sem redução
  /// (docs/comprovantes-ia.md, seção 2).
  static const maxSide = 2576.0;

  /// Da galeria, reduzida a [maxSide]. Nulo se a pessoa desistiu.
  Future<PickedFile?> pickImage() async {
    final file = await _images.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  /// Só `.pdf`. Nulo se a pessoa desistiu.
  Future<PickedFile?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }
}

final receiptPickerProvider = Provider<ReceiptPicker>((ref) => ReceiptPicker());
