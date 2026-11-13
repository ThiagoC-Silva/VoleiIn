import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../domain/identities.dart' as identities;
import 'google_auth_client.dart';

/// Única camada que fala com o Supabase Auth (docs/arquitetura-app.md, seção 2).
///
/// Os fluxos por código (cadastro, recuperação e troca de e-mail) seguem o
/// ADR 0017 e a tabela da seção 9 de specs/001-conta-e-perfil/research.md.
class AuthRepository {
  AuthRepository(this._client, this._google);

  final SupabaseClient _client;
  final GoogleAuthClient _google;

  GoTrueClient get _auth => _client.auth;

  /// Sessão guardada pelo próprio `supabase_flutter` (RF05).
  bool get hasSession => _auth.currentSession != null;

  String? get currentUserId => _auth.currentUser?.id;

  String? get currentEmail => _auth.currentUser?.email;

  /// Acesso por e-mail e senha (U07): decide as linhas Trocar e-mail e Trocar
  /// senha e as rotas delas (docs/ui/telas.md, 5.7).
  bool get hasEmailPassword => hasEmailPasswordFor(_auth.currentUser);

  static bool hasEmailPasswordFor(User? user) => identities.hasEmailPassword(
    (user?.identities ?? const <UserIdentity>[]).map((i) => i.provider),
  );

  /// Entradas e saídas da sessão, inclusive a invalidação do token.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => guard(() async {
    await _auth.signInWithPassword(email: email, password: password);
  });

  /// RF01. O nome vai nos metadados (`name`), de onde a trigger do perfil o lê.
  /// E-mail que já tem conta responde como sucesso, sem enviar código.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) => guard(() async {
    await _auth.signUp(email: email, password: password, data: {'name': name});
  });

  /// RF02: confirma o cadastro e cria a sessão.
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) => guard(() async {
    await _auth.verifyOTP(type: OtpType.email, email: email, token: code);
  });

  Future<void> resendSignupCode(String email) => guard(() async {
    await _auth.resend(type: OtpType.signup, email: email);
  });

  /// RF06, etapa 1. Responde igual para e-mail com e sem conta.
  Future<void> sendRecoveryCode(String email) => guard(() async {
    await _auth.resetPasswordForEmail(email);
  });

  /// RF06, etapa 2: o código vale e cria a sessão.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => guard(() async {
    await _auth.verifyOTP(type: OtpType.recovery, email: email, token: code);
  });

  /// Senha nova, na recuperação (RF06) e na troca logada (RF107).
  Future<void> updatePassword(String password) => guard(() async {
    await _auth.updateUser(UserAttributes(password: password));
  });

  /// RF106, etapa 1: o código vai só ao endereço novo.
  Future<void> requestEmailChange(String newEmail) => guard(() async {
    await _auth.updateUser(UserAttributes(email: newEmail));
  });

  /// RF106, etapa 2.
  Future<void> verifyEmailChange({
    required String newEmail,
    required String code,
  }) => guard(() async {
    await _auth.verifyOTP(
      type: OtpType.emailChange,
      email: newEmail,
      token: code,
    );
  });

  /// RF107: confere a senha atual entrando de novo com o e-mail da conta.
  Future<void> reauthenticate(String password) => guard(() async {
    final email = currentEmail;
    if (email == null) throw const AppException(ErrorCode.notAuthenticated);
    await _auth.signInWithPassword(email: email, password: password);
  });

  /// RF03 e RF108. Devolve `false` se a pessoa fechou o seletor (E12).
  /// A vinculação com uma conta de mesmo e-mail é feita pelo Supabase Auth.
  Future<bool> signInWithGoogle() async {
    final String? idToken;
    try {
      idToken = await _google.fetchIdToken();
    } catch (_) {
      throw const AppException(ErrorCode.authGoogleFailed);
    }
    if (idToken == null) return false;
    await guard(() async {
      await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken!,
      );
    });
    return true;
  }

  /// RF07. Encerra também a sessão do Google, ignorando falha dele. A remoção
  /// do token de push entra na fatia 7.
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Sem conta Google na sessão, ou o Google indisponível: não impede sair.
    }
    await guard(() async {
      await _auth.signOut();
    });
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(supabaseProvider),
    ref.watch(googleAuthClientProvider),
  ),
);
