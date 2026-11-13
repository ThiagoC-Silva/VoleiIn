import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../data/auth_repository.dart';
import 'code_sent_text.dart';
import 'pending_email_provider.dart';

final _confirmProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Confirmar o e-mail do cadastro com o código (RF02, ADR 0017;
/// docs/ui/telas.md, 5.3; confirmEmail.png).
///
/// Chega aqui pelo cadastro ou pelo erro `email_not_confirmed` do login, com o
/// e-mail em memória. Sem ele (app reaberto), volta ao login.
class ConfirmEmailScreen extends ConsumerStatefulWidget {
  const ConfirmEmailScreen({super.key});

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  final _code = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _code.addListener(_clearErrorWhileTyping);
    if (ref.read(pendingEmailProvider) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.goNamed(Routes.login);
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _clearErrorWhileTyping() {
    if (_codeError != null && _code.text.isNotEmpty) {
      setState(() => _codeError = null);
    }
  }

  Future<void> _verify(String code) async {
    final email = ref.read(pendingEmailProvider);
    if (email == null || code.length != CodeField.length) return;
    if (ref.read(_confirmProvider).isLoading) return;

    final ok = await ref
        .read(_confirmProvider.notifier)
        .run(
          () => ref
              .read(authRepositoryProvider)
              .verifySignupCode(email: email, code: code),
        );
    if (!mounted) return;
    if (ok) {
      // A sessão nasceu: o roteador leva à conferência dos termos.
      ref.read(pendingEmailProvider.notifier).set(null);
      ref.read(signupDraftProvider.notifier).set(null);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final error = ref.read(_confirmProvider).error!;
    if (error is AppException && error.code == ErrorCode.authInvalidCode) {
      // Código errado ou vencido: erro no campo, que é limpo.
      setState(() => _codeError = errorTextFor(l10n, error));
      _code.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorTextFor(l10n, error))));
    }
  }

  Future<bool> _resend() async {
    final email = ref.read(pendingEmailProvider);
    if (email == null) return false;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).resendSignupCode(email);
      messenger.showSnackBar(SnackBar(content: Text(l10n.authCodeResent)));
      return true;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorTextFor(l10n, error))),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = ref.watch(pendingEmailProvider) ?? '';
    final verifying = ref.watch(_confirmProvider).isLoading;

    return PopScope(
      canPop: false,
      // O voltar leva ao login, e não ao cadastro (S02).
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(Routes.login);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccessHeader(
                        icon: Symbols.mark_email_unread,
                        // O hífen de "e-mail" não quebra (referencias/README).
                        title: Text(
                          nonBreakingHyphens(l10n.authConfirmEmailTitle),
                        ),
                        subtitle: BoldValueText(
                          text: l10n.authCodeSent(email),
                          value: email,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CodeField(
                        controller: _code,
                        enabled: !verifying,
                        errorText: _codeError,
                        semanticLabel: l10n.authCodeLabel,
                        onCompleted: _verify,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: l10n.authConfirmButton,
                        loading: verifying,
                        onPressed: () => _verify(_code.text),
                      ),
                      const SizedBox(height: 16),
                      ResendCodeButton(onResend: _resend),
                      const SizedBox(height: 16),
                      Text(
                        l10n.authConfirmEmailHelp,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton(
                  onPressed: verifying
                      ? null
                      : () => context.goNamed(Routes.signup),
                  child: Text(l10n.authUseAnotherEmail),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cerca o hífen com a junção de palavras (U+2060), para "e-mail" não quebrar
/// no fim da linha. A Montserrat não tem o hífen não separável (U+2011), e a
/// junção é invisível: não depende de glifo.
String nonBreakingHyphens(String text) => text.replaceAll('-', '\u2060-\u2060');
