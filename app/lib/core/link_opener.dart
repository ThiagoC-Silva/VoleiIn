import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre um link fora do app (o Google Maps do jogo; o discador e o WhatsApp
/// na etapa C), pelo `url_launcher` (docs/arquitetura-app.md, seção 3).
/// Trocável por dublê nos testes, como o `Sharer`.
class LinkOpener {
  const LinkOpener();

  /// Falso se nenhum app do aparelho abre o link (`commonCannotOpenLink`).
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final linkOpenerProvider = Provider<LinkOpener>((ref) => const LinkOpener());
