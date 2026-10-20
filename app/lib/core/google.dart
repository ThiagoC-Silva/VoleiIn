import 'package:google_sign_in/google_sign_in.dart';

// ID do cliente web do Google Cloud, passado no build por --dart-define.
// É o destinatário do ID token que o Supabase confere; não é segredo. O segredo fica no Supabase.
const _clienteWeb = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

Future<void> iniciarGoogle() async {
  if (_clienteWeb.isEmpty) {
    throw StateError(
      'Falta GOOGLE_WEB_CLIENT_ID: rode com --dart-define (ver CLAUDE.md da raiz).',
    );
  }
  await GoogleSignIn.instance.initialize(serverClientId: _clienteWeb);
}
