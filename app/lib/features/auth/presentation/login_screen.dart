import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/footer_link.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'pending_email_provider.dart';

final _loginProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );
final _googleProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Login (docs/ui/telas.md, 4.1 e 5.1; login.png).
///
/// Entrar com e-mail e senha, Esqueci minha senha, Continuar com Google e Criar
/// conta. O redirecionamento depois de entrar é do roteador.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void _showError(Object? error, {SnackBarAction? action}) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorTextFor(l10n, error ?? '')), action: action),
    );
  }

  Future<void> _submit() async {
    // Campo vazio: erro no campo, sem chamar o servidor.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final ok = await ref
        .read(_loginProvider.notifier)
        .run(
          () => _auth.signInWithPassword(
            email: email,
            password: _passwordController.text,
          ),
        );
    if (ok || !mounted) return;

    final error = ref.read(_loginProvider).error;
    final notConfirmed =
        error is AppException && error.code == ErrorCode.authEmailNotConfirmed;
    _showError(
      error,
      action: notConfirmed
          ? SnackBarAction(
              label: AppLocalizations.of(context).authConfirmAction,
              onPressed: () => _confirmEmail(email),
            )
          : null,
    );
  }

  /// E-mail ainda não confirmado: pede um código novo e abre a confirmação
  /// (docs/ui/telas.md, 5.1).
  Future<void> _confirmEmail(String email) async {
    try {
      await _auth.resendSignupCode(email);
    } catch (error) {
      if (mounted) _showError(error);
      return;
    }
    if (!mounted) return;
    ref.read(pendingEmailProvider.notifier).set(email);
    context.goNamed(Routes.confirmEmail);
  }

  Future<void> _google() async {
    final ok = await ref
        .read(_googleProvider.notifier)
        .run(() => _auth.signInWithGoogle());
    // Seletor fechado devolve false sem erro: nada acontece (E12).
    if (ok || !mounted) return;
    _showError(ref.read(_googleProvider).error);
  }

  void _forgotPassword() {
    final email = _emailController.text.trim();
    ref.read(pendingEmailProvider.notifier).set(email.isEmpty ? null : email);
    context.pushNamed(Routes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submitting = ref.watch(_loginProvider).isLoading;
    final googling = ref.watch(_googleProvider).isLoading;
    final busy = submitting || googling;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LoginHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    // O autofill do Android só enxerga os campos dentro de um
                    // grupo.
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FieldLabel(l10n.authEmailLabel),
                            TextFormField(
                              controller: _emailController,
                              enabled: !busy,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              // O app não valida o formato: quem decide é o Auth.
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? l10n.authEmailRequired
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            FieldLabel(l10n.authPasswordLabel),
                            PasswordField(
                              controller: _passwordController,
                              enabled: !busy,
                              onSubmitted: (_) {
                                if (!busy) _submit();
                              },
                              validator: (value) => (value ?? '').isEmpty
                                  ? l10n.authPasswordRequired
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: busy ? null : _forgotPassword,
                                child: Text(l10n.authForgotPassword),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: l10n.authLoginButton,
                              loading: submitting,
                              onPressed: busy ? null : _submit,
                            ),
                            const SizedBox(height: 16),
                            _OrDivider(label: l10n.authOr),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: busy ? null : _google,
                              icon: googling
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Symbols.account_circle),
                              label: Text(l10n.authContinueWithGoogle),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: FooterLink(
              text: l10n.authNoAccount,
              action: l10n.authCreateAccount,
              onPressed: busy ? null : () => context.pushNamed(Routes.signup),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco amarelo do topo, com o espaço reservado do logo (design-system.md,
/// 7.17; login.png).
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 48,
        24,
        32,
      ),
      decoration: BoxDecoration(
        color: colors.game,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 44,
              color: colors.onBlock,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.authLoginSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.onBlock,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
