import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/app_localizations.dart';
import 'login_controller.dart';

/// Login com e-mail e senha (docs/ui/telas.md, seção 4.1).
///
/// A fatia 2 acrescenta "Entrar com Google", "Criar conta" e
/// "Esqueci minha senha", sem refazer o que já existe.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;

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
    final ok = await ref.read(loginControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (ok || !mounted) return;

    // Erro de ação: SnackBar, e a tela continua como estava.
    final error = ref.read(loginControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorTextFor(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final submitting = ref.watch(loginControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            // O autofill do Android só enxerga os campos dentro de um grupo.
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Espaço reservado do logo (design-system.md, 7.17).
                    Text(l10n.appTitle, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authLoginSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _FieldLabel(l10n.authEmailLabel),
                    TextFormField(
                      controller: _emailController,
                      enabled: !submitting,
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
                    _FieldLabel(l10n.authPasswordLabel),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !submitting,
                      obscureText: !_passwordVisible,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!submitting) _submit();
                      },
                      validator: (value) =>
                          (value ?? '').isEmpty ? l10n.authPasswordRequired : null,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          // Área de toque de 48 x 48 e rótulo para o TalkBack.
                          iconSize: 24,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: _passwordVisible
                              ? l10n.authHidePassword
                              : l10n.authShowPassword,
                          icon: Icon(
                            _passwordVisible
                                ? Symbols.visibility_off
                                : Symbols.visibility,
                          ),
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Text(l10n.authLoginButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo acima do campo, fora dele (design-system.md, 7.2).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
