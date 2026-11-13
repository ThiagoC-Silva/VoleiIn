import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/footer_link.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'pending_email_provider.dart';

final _signupProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Tamanho mínimo da senha, igual ao `minimum_password_length` do Supabase Auth
/// (docs/ui/telas.md, seção 5; docs/setup.md, 6.1).
const minPasswordLength = 8;

/// Cadastro com nome, e-mail e senha (RF01; docs/ui/telas.md, 5.2; signup.png).
/// Não há caixa de aceite: o aceite é feito na `/terms`.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    // "Usar outro e-mail" volta com os campos preenchidos (telas.md, 5.3).
    final draft = ref.read(signupDraftProvider);
    _name = TextEditingController(text: draft?.name);
    _email = TextEditingController(text: draft?.email);
    _password = TextEditingController(text: draft?.password);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    final ok = await ref
        .read(_signupProvider.notifier)
        .run(
          () => ref
              .read(authRepositoryProvider)
              .signUp(name: name, email: email, password: password),
        );
    if (!mounted) return;
    if (!ok) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorTextFor(l10n, ref.read(_signupProvider).error!)),
        ),
      );
      return;
    }
    // E-mail que já tem conta também chega aqui: o Auth não revela quem tem
    // conta, e a confirmação explica o que fazer (telas.md, 5.2).
    ref
        .read(signupDraftProvider.notifier)
        .set(SignupDraft(name: name, email: email, password: password));
    ref.read(pendingEmailProvider.notifier).set(email);
    // Troca a tela: o cadastro sai da pilha (S02).
    context.goNamed(Routes.confirmEmail);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final submitting = ref.watch(_signupProvider).isLoading;

    return InnerScaffold(
      title: l10n.authCreateAccount,
      footer: FooterLink(
        text: l10n.authHasAccount,
        action: l10n.authGoToLogin,
        onPressed: submitting ? null : () => context.goNamed(Routes.login),
      ),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.authSignupSubtitle, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              FieldLabel(l10n.authNameLabel),
              TextFormField(
                controller: _name,
                enabled: !submitting,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.isEmpty) return l10n.authNameRequired;
                  if (name.length > 80) return l10n.authNameTooLong;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.authEmailLabel),
              TextFormField(
                controller: _email,
                enabled: !submitting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.authEmailRequired
                    : null,
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.authPasswordLabel),
              PasswordField(
                controller: _password,
                enabled: !submitting,
                newPassword: true,
                onSubmitted: (_) {
                  if (!submitting) _submit();
                },
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return l10n.authPasswordRequired;
                  if (password.length < minPasswordLength) {
                    return l10n.authPasswordTooShort;
                  }
                  return null;
                },
              ),
              FieldHint(l10n.authPasswordHint),
              const SizedBox(height: 24),
              PrimaryButton(
                label: l10n.authCreateAccountButton,
                loading: submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
