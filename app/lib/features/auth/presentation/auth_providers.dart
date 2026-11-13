import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Sessão: um `StreamProvider` sobre `onAuthStateChange`
/// (docs/arquitetura-app.md, seção 5).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// Id de quem está logado. Muda só quando o usuário muda, e não a cada
/// renovação do token: é o que faz a conferência dos termos rodar de novo.
final sessionUserIdProvider = Provider<String?>((ref) {
  final fromStream = ref.watch(
    authStateProvider.select((state) => state.value?.session?.user.id),
  );
  return fromStream ?? ref.read(authRepositoryProvider).currentUserId;
});
