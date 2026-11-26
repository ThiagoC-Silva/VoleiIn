/// Tamanho de arquivo, só com inteiros (docs/copy.md, 10.2): `188416` vira
/// `184 KB`; `2516582` vira `2,4 MB`. Abaixo de 1 KB, `1 KB`.
String formatFileSize(int bytes) {
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes < mb) {
    final kilobytes = (bytes + kb ~/ 2) ~/ kb;
    return '${kilobytes < 1 ? 1 : kilobytes} KB';
  }
  final tenths = (bytes * 10 + mb ~/ 2) ~/ mb;
  return '${tenths ~/ 10},${tenths % 10} MB';
}
