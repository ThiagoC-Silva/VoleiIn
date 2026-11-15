import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilhamento do Android (`share_plus`), trocável por dublê nos testes
/// (specs/002-grupos/contracts/repositories.md).
class Sharer {
  const Sharer();

  /// Abre o seletor do Android com o texto. Fechar o seletor não é erro.
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}

final sharerProvider = Provider<Sharer>((ref) => const Sharer());
