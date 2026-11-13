import 'package:flutter_riverpod/flutter_riverpod.dart';

/// E-mail do código pendente (cadastro, recuperação e troca de e-mail), só em
/// memória, nunca no aparelho nem na rota (docs/arquitetura-app.md, seção 9).
class PendingEmailNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? email) => state = email;
}

final pendingEmailProvider = NotifierProvider<PendingEmailNotifier, String?>(
  PendingEmailNotifier.new,
);

/// Campos do cadastro, para "Usar outro e-mail" voltar com eles preenchidos
/// (docs/ui/telas.md, 5.3). Só em memória.
class SignupDraft {
  const SignupDraft({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;
}

class SignupDraftNotifier extends Notifier<SignupDraft?> {
  @override
  SignupDraft? build() => null;

  void set(SignupDraft? draft) => state = draft;
}

final signupDraftProvider = NotifierProvider<SignupDraftNotifier, SignupDraft?>(
  SignupDraftNotifier.new,
);

/// Ligado entre o código da recuperação valer (que cria a sessão) e a senha
/// nova ser gravada, para o roteador não tirar a pessoa da tela no meio
/// (docs/ui/telas.md, 5.4).
class RecoveryInProgressNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final recoveryInProgressProvider =
    NotifierProvider<RecoveryInProgressNotifier, bool>(
      RecoveryInProgressNotifier.new,
    );
