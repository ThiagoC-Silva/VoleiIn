import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import '../data/terms_repository.dart';
import '../domain/terms.dart';

/// Sessão: um `StreamProvider` sobre `onAuthStateChange`
/// (docs/arquitetura-app.md, seção 5).
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// Usuário da sessão, recalculado a cada evento de `onAuthStateChange`. Só
/// avisa quem depende dele quando o usuário muda (outro login ou saída).
final sessionUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUserId;
});

/// Nome, e-mail e senha do cadastro ou do login em andamento
/// (specs/001-conta-e-perfil/data-model.md). Só em memória, nunca no aparelho
/// nem na rota (docs/arquitetura-app.md, seção 9).
class AccessDraft {
  const AccessDraft({this.name = '', this.email = '', this.password = ''});

  final String name;
  final String email;
  final String password;
}

class AccessDraftNotifier extends Notifier<AccessDraft?> {
  @override
  AccessDraft? build() => null;

  void save({String name = '', String email = '', String password = ''}) =>
      state = AccessDraft(name: name, email: email, password: password);

  void clear() => state = null;
}

final accessDraftProvider = NotifierProvider<AccessDraftNotifier, AccessDraft?>(
  AccessDraftNotifier.new,
);

/// Se a `/forgot-password` está entre o código e a senha (research R2). O
/// código de recuperação cria a sessão antes de a senha nova ser gravada, e o
/// roteador não pode tirar a pessoa da tela nesse meio-tempo.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  void finish() => state = false;
}

final passwordRecoveryInProgressProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
      PasswordRecoveryNotifier.new,
    );

/// O que falta aceitar dos termos (docs/ui/telas.md, 3.1; research R3). Roda
/// ao abrir o app com sessão e depois de cada login, e fica em memória até a
/// sessão acabar ou o aceite ser gravado.
final termsStatusProvider = FutureProvider<TermsStatus>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) throw const AppException(ErrorCode.notAuthenticated);
  final repository = ref.watch(termsRepositoryProvider);
  final results = await Future.wait([
    repository.currentVersions(),
    repository.ownAcceptances(),
  ]);
  return TermsStatus.from(current: results[0], accepted: results[1]);
});
