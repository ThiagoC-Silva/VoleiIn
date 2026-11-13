import 'dart:typed_data';

/// Tipos de foto aceitos pelo bucket `avatars` (RN106).
enum ImageType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const ImageType(this.mimeType, this.extension);

  final String mimeType;
  final String extension;

  /// Tipo pelos primeiros bytes do arquivo, e não pelo nome, que pode mentir.
  /// Nulo se não for JPEG, PNG nem WebP.
  static ImageType? detect(Uint8List bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return ImageType.jpeg;
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return ImageType.png;
    }
    // RIFF....WEBP
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return ImageType.webp;
    }
    return null;
  }
}
