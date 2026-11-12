/// Variáveis de ambiente, lidas de `--dart-define-from-file`
/// (docs/setup.md, seção 5.1). No app só entram identificadores públicos.
///
/// As mensagens desta classe são para quem desenvolve e ficam em inglês
/// (docs/copy.md, seção 4): o build de produção sai do pipeline com todas as
/// variáveis preenchidas, então o usuário nunca as vê.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Usado pelo login com Google, a partir da fatia 2.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Para a abertura logo no `main` se faltar alguma variável desta fatia.
  static void ensureComplete() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing --dart-define values: ${missing.join(', ')}. '
        'Run with --dart-define-from-file=env/local.json (see docs/setup.md).',
      );
    }
  }
}
