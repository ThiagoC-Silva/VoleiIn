import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';

/// Única camada que fala com o Supabase Auth (docs/arquitetura-app.md, seção 2).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sessão guardada pelo próprio `supabase_flutter` (RF05).
  bool get hasSession => _client.auth.currentSession != null;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Entradas e saídas da sessão, inclusive a invalidação do token.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => guard(() async {
    await _client.auth.signInWithPassword(email: email, password: password);
  });

  /// A remoção do token de push entra nas fatias 2 e 7 (RF07).
  Future<void> signOut() => guard(() async {
    await _client.auth.signOut();
  });
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider)),
);
