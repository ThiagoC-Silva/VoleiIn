import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/terms_repository.dart';
import '../domain/terms.dart';
import 'auth_providers.dart';

/// Conferência dos termos (RF105; docs/ui/telas.md, 3.1). Roda ao abrir o app
/// com sessão e depois de cada login, e é refeita depois do aceite. Fica em
/// memória até a sessão mudar. Nulo sem sessão.
final termsStatusProvider = FutureProvider<TermsStatus?>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return null;
  return ref.watch(termsRepositoryProvider).fetchStatus();
});
