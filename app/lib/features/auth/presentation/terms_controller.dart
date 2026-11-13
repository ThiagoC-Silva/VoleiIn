import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../data/auth_repository.dart';
import '../data/terms_repository.dart';
import '../domain/terms.dart';
import 'auth_providers.dart';
import 'submit_controller.dart';

/// Resultado do Aceitar e continuar.
enum TermsAcceptResult {
  accepted,

  /// A versão mudou no servidor entre abrir e aceitar: a tela relê as versões
  /// e desmarca a caixa (docs/ui/telas.md, 5.5).
  versionChanged,

  failed,
}

/// Aceite dos termos (RF105; docs/ui/telas.md, 5.5).
class TermsController extends SubmitController {
  TermsRepository get _terms => ref.read(termsRepositoryProvider);

  AppException? lastError;

  /// Grava uma linha por documento que falta, com a versão vigente.
  Future<TermsAcceptResult> accept(TermsStatus status) async {
    lastError = await submit(() => _terms.accept(status.missing));
    if (!ref.mounted) return TermsAcceptResult.failed;
    if (lastError == null) {
      // A conferência relê do servidor e libera o roteador.
      ref.invalidate(termsStatusProvider);
      return TermsAcceptResult.accepted;
    }
    // Sem conexão não é recusa: a caixa continua marcada.
    if (lastError!.code == ErrorCode.noConnection) {
      return TermsAcceptResult.failed;
    }
    // O RLS recusa a versão que deixou de ser a vigente (42501, que chega como
    // internalError). Relê as versões para saber se foi isso.
    try {
      final current = await _terms.currentVersions();
      if (!ref.mounted) return TermsAcceptResult.failed;
      if (!setEquals(current.toSet(), status.current.toSet())) {
        ref.invalidate(termsStatusProvider);
        return TermsAcceptResult.versionChanged;
      }
    } catch (_) {
      // Fica o erro do aceite.
    }
    return TermsAcceptResult.failed;
  }

  Future<AppException?> signOut() =>
      submit(() => ref.read(authRepositoryProvider).signOut());
}

final termsControllerProvider =
    AsyncNotifierProvider.autoDispose<TermsController, void>(
      TermsController.new,
    );
