import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../domain/auth_access.dart' as access;
import 'google_id_token_source.dart';

/// Única camada que fala com o Supabase Auth (docs/arquitetura-app.md, seção 2;
/// specs/001-conta-e-perfil/contracts/repositories.md).
class AuthRepository {
  AuthRepository(this._auth, this._google);

  final GoTrueClient _auth;
  final GoogleIdTokenSource _google;

  /// Sessão guardada pelo próprio `supabase_flutter` (RF05).
  bool get hasSession => _auth.currentSession != null;

  String? get currentUserId => _auth.currentUser?.id;

  String? get currentEmail => _auth.currentUser?.email;

  /// Se a conta tem a identidade `email` (docs/ui/telas.md, 5.7).
  bool get hasEmailAccess => access.hasEmailAccess(
    _auth.currentUser?.identities?.map((i) => i.provider) ?? const [],
  );

  /// Entradas e saídas da sessão, inclusive a invalidação do token.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => guard(() async {
    await _auth.signInWithPassword(email: email, password: password);
  });

  /// Falso quando a pessoa fecha o seletor, sem erro (E12). Cria a conta de
  /// quem ainda não tem e vincula ao cadastro por e-mail (RF03, RF108).
  Future<bool> signInWithGoogle() => guard(() async {
    final idToken = await _google.idToken();
    if (idToken == null) return false;
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    return true;
  });

  /// O nome vai nos metadados, e a *trigger* de `auth.users` cria o perfil
  /// com ele quando o e-mail for confirmado (RF01).
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => guard(() async {
    await _auth.signUp(email: email, password: password, data: {'name': name});
  });

  /// Confere o código e grava de novo a senha digitada (research R5): o
  /// cadastro repetido de um e-mail não confirmado mantém a senha do primeiro
  /// pedido, que pode não ser desta pessoa.
  Future<void> confirmSignup({
    required String email,
    required String code,
    required String password,
  }) => guard(() async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.email);
    try {
      await _auth.updateUser(UserAttributes(password: password));
    } catch (error) {
      // A senha já é a da conta: é o caso comum.
      if (toAppException(error).code != ErrorCode.authSamePassword) rethrow;
    }
  });

  Future<void> resendSignupCode(String email) => guard(() async {
    await _auth.resend(email: email, type: OtpType.signup);
  });

  /// Serve também para reenviar o código (RF06).
  Future<void> sendPasswordRecovery(String email) => guard(() async {
    await _auth.resetPasswordForEmail(email);
  });

  /// Cria a sessão (docs/ui/telas.md, 5.4).
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => guard(() async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  });

  Future<void> updatePassword(String newPassword) => guard(() async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  });

  /// Confere a senha atual entrando de novo no e-mail da conta (RF107).
  Future<void> verifyCurrentPassword(String password) => guard(() async {
    final email = currentEmail;
    if (email == null) throw const AppException(ErrorCode.notAuthenticated);
    await _auth.signInWithPassword(email: email, password: password);
  });

  /// O código vai só ao endereço novo (RF106). Serve também para reenviar.
  Future<void> requestEmailChange(String newEmail) => guard(() async {
    await _auth.updateUser(UserAttributes(email: newEmail));
  });

  Future<void> confirmEmailChange({
    required String newEmail,
    required String code,
  }) => guard(() async {
    await _auth.verifyOTP(
      email: newEmail,
      token: code,
      type: OtpType.emailChange,
    );
  });

  /// Encerra a sessão do Supabase Auth e a do Google (RF07). A remoção do
  /// token de push entra na fatia 7.
  Future<void> signOut() => guard(() async {
    await _auth.signOut();
    await _google.signOut();
  });
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(supabaseProvider).auth,
    ref.watch(googleIdTokenSourceProvider),
  ),
);
