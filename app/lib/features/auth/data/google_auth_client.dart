import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/env.dart';

/// Seletor de contas do Google, atrás de uma interface para os testes
/// (specs/001-conta-e-perfil/research.md, 8).
abstract interface class GoogleAuthClient {
  /// `idToken` da conta escolhida, ou nulo se a pessoa fechou o seletor.
  /// Outra falha sobe como exceção.
  Future<String?> fetchIdToken();

  /// Encerra a sessão do Google, para o seletor aparecer na próxima entrada.
  Future<void> signOut();
}

/// Implementação com o `google_sign_in` 7 (Credential Manager no Android).
class GoogleSignInClient implements GoogleAuthClient {
  GoogleSignInClient(this._serverClientId);

  final String _serverClientId;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() => _initialization ??= GoogleSignIn.instance
      .initialize(serverClientId: _serverClientId);

  @override
  Future<String?> fetchIdToken() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      // Fechar o seletor não é erro (docs/copy.md, 6.8; cenário E12).
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}

final googleAuthClientProvider = Provider<GoogleAuthClient>(
  (ref) => GoogleSignInClient(Env.googleWebClientId),
);
