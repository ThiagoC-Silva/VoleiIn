import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controller de ação (formulário, botão), com o estado da submissão
/// (docs/arquitetura-app.md, seção 5). Cada tela declara o seu provider
/// `autoDispose`, para o estado não vazar entre telas:
///
/// ```dart
/// final _saveProvider =
///     AsyncNotifierProvider.autoDispose<ActionController, void>(ActionController.new);
/// ```
///
/// O erro fica em `state.error`, já convertido em `AppException` pelo
/// repositório. Depois de uma mutação, a tela invalida as leituras afetadas.
class ActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Roda a ação e devolve `true` se deu certo.
  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}
