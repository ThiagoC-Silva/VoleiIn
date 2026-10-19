import 'package:supabase_flutter/supabase_flutter.dart';

// Endereço e chave pública do projeto, passados no build por --dart-define.
// A chave pública só alcança o que a política de linha libera; a de serviço nunca entra no app.
const _url = String.fromEnvironment('SUPABASE_URL');
const _chavePublica = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> iniciarSupabase() async {
  if (_url.isEmpty || _chavePublica.isEmpty) {
    throw StateError(
      'Faltam SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY: rode com --dart-define (ver CLAUDE.md da raiz).',
    );
  }
  await Supabase.initialize(url: _url, publishableKey: _chavePublica);
}
