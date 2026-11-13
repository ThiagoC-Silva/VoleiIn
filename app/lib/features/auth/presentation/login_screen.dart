import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/snack.dart';
import 'login_controller.dart';

/// Login (docs/ui/telas.md, 4.1 e 5.1; login.png).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Qual botão mostra o indicador. Os dois ficam bloqueados até o fim.
  bool _googleBusy = false;

  LoginController get _controller => ref.read(loginControllerProvider.notifier);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Campo vazio: erro no campo, sem chamar o servidor.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context);
    final ok = await _controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (ok || !mounted) return;

    // Erro de ação: SnackBar, e a tela continua como estava.
    final error = ref.read(loginControllerProvider).error;
    if (error == null) return;
    showSnack(
      context,
      errorTextFor(l10n, error),
      action: isEmailNotConfirmed(error)
          ? SnackBarAction(
              label: l10n.authConfirmAction,
              onPressed: _confirmEmail,
            )
          : null,
    );
  }

  /// Guarda o e-mail, pede um código novo e abre a `/confirm-email`.
  Future<void> _confirmEmail() async {
    final error = await _controller.resendConfirmation(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (error != null) showErrorSnack(context, error);
    context.pushNamed(Routes.confirmEmail);
  }

  Future<void> _google() async {
    setState(() => _googleBusy = true);
    final error = await _controller.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleBusy = false);
    if (error != null) showErrorSnack(context, error);
  }

  void _forgotPassword() {
    _controller.rememberEmail(_emailController.text);
    context.pushNamed(Routes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(l10n: l10n)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              // O autofill do Android só enxerga os campos dentro de um grupo.
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LabeledField(
                        label: l10n.authEmailLabel,
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
                      PasswordField(
                        label: l10n.authPasswordLabel,
                        controller: _passwordController,
                        enabled: !busy,
                        onFieldSubmitted: (_) {
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
                        loading: busy && !_googleBusy,
                        onPressed: busy ? null : _submit,
                      ),
                      const SizedBox(height: 16),
                      _OrDivider(label: l10n.authOr),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _google,
                        icon: busy && _googleBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Symbols.account_circle),
                        label: Text(
                          l10n.authContinueWithGoogle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.authNoAccount,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => context.pushNamed(Routes.signup),
                            child: Text(l10n.authCreateAccount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco amarelo do topo, com o espaço reservado do logo
/// (design-system.md, 7.8 e 7.17; login.png).
class _Hero extends StatelessWidget {
  const _Hero({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBlock = theme.colorScheme.onPrimary;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 40,
        24,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 40,
              color: onBlock,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.authLoginSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onBlock,
              fontWeight: FontWeight.w500,
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
