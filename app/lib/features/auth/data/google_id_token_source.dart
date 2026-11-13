import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/env.dart';
import '../../../core/errors/error_code.dart';

/// O ID token do Google, atrás de uma classe pequena para o repositório ser
/// testável sem o plugin (research R1).
class GoogleIdTokenSource {
  GoogleIdTokenSource([GoogleSignIn? google])
    : _google = google ?? GoogleSignIn.instance;

  final GoogleSignIn _google;
  Future<void>? _initialized;

  /// O `serverClientId` é o cliente web: é dele o `aud` que o Supabase Auth
  /// confere no token (docs/setup.md, 6.2).
  Future<void> _ensureInitialized() => _initialized ??= _google.initialize(
    serverClientId: Env.googleWebClientId,
  );

  /// O ID token da conta escolhida, ou nulo se a pessoa fechou o seletor.
  /// Outra falha lança `AppException(authGoogleFailed)`.
  ///
  /// Sem o SHA-1 da chave cadastrado no Google Cloud, o Play Services também
  /// responde `canceled`, e a tela fica muda (docs/setup.md, 6.2).
  Future<String?> idToken() async {
    try {
      await _ensureInitialized();
      final account = await _google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AppException(ErrorCode.authGoogleFailed);
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const AppException(ErrorCode.authGoogleFailed);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(ErrorCode.authGoogleFailed);
    }
  }

  /// Encerra a sessão do Google, para o seletor aparecer na próxima entrada.
  /// Falha é ignorada: a sessão do app já acabou.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _google.signOut();
    } catch (_) {}
  }
}

final googleIdTokenSourceProvider = Provider<GoogleIdTokenSource>(
  (ref) => GoogleIdTokenSource(),
);
