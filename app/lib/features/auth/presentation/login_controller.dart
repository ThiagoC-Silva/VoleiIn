import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Ação de entrar, com o estado da submissão (docs/arquitetura-app.md, seção 5).
class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Devolve `true` quando entrou. O redirecionamento é do roteador.
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPassword(
            email: email.trim(),
            password: password,
          ),
    );
    return !state.hasError;
  }
}

final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(LoginController.new);
