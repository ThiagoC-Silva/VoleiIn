import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import 'access_validators.dart';
import 'auth_providers.dart';
import 'signup_controller.dart';

/// Cadastro (docs/ui/telas.md, 5.2; signup.png). Sem caixa de aceite: o aceite
/// é na `/terms`, depois do primeiro acesso.
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
    // "Usar outro e-mail" volta para cá com os campos preenchidos.
    final draft = ref.read(accessDraftProvider);
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
    final error = await ref
        .read(signupControllerProvider.notifier)
        .signUp(name: _name.text, email: _email.text, password: _password.text);
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    // A confirmação sai da pilha do cadastro: o voltar não retorna.
    context.pushReplacementNamed(Routes.confirmEmail);
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final validators = AccessValidators(l10n);
    final busy = ref.watch(signupControllerProvider).isLoading;

    return Scaffold(
      appBar: InnerAppBar(title: l10n.authCreateAccount),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: FormScrollView(
            content: [
              Text(l10n.authSignupSubtitle, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              LabeledField(
                label: l10n.authNameLabel,
                controller: _name,
                enabled: !busy,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: validators.name,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: l10n.authEmailLabel,
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: validators.email,
              ),
              const SizedBox(height: 16),
              PasswordField(
                label: l10n.authPasswordLabel,
                controller: _password,
                enabled: !busy,
                newPassword: true,
                helperText: l10n.authPasswordHint,
                validator: validators.newPassword,
                onFieldSubmitted: (_) {
                  if (!busy) _submit();
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: l10n.authCreateAccountButton,
                loading: busy,
                onPressed: _submit,
              ),
            ],
            footer: [
              _FooterLink(
                text: l10n.authHasAccount,
                action: l10n.authGoToLogin,
                onPressed: busy ? null : _goToLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frase do pé da tela com o botão de texto ("Já tem conta? Entrar").
class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
