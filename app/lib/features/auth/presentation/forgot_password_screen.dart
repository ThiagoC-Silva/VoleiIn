import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/bold_value_text.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../../../shared/widgets/snack.dart';
import 'access_validators.dart';
import 'auth_providers.dart';
import 'forgot_password_controller.dart';

/// Recuperar senha (docs/ui/telas.md, 5.4; forgotPassword-etapa1.png e
/// forgotPassword-etapa2.png). Duas etapas na mesma rota.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  RecoveryStep _step = RecoveryStep.email;
  String? _codeError;
  String? _passwordError;

  ForgotPasswordController get _controller =>
      ref.read(forgotPasswordControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Preenchido com o e-mail digitado no login, se houver.
    _email = TextEditingController(text: ref.read(accessDraftProvider)?.email);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    final error = await _controller.sendCode(_email.text);
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    setState(() => _step = RecoveryStep.code);
  }

  /// O sexto dígito leva à senha; se ela já está digitada, salva.
  void _codeCompleted() {
    if (AccessValidators(AppLocalizations.of(context))
            .newPassword(_password.text) ==
        null) {
      _save();
    } else {
      _passwordFocus.requestFocus();
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _codeError = null;
      _passwordError = null;
    });
    await afterServerErrorCleared();
    if (!mounted) return;
    if (!(_passwordForm.currentState?.validate() ?? false)) return;

    final (RecoveryStep, AppException?) result;
    if (_step == RecoveryStep.password) {
      result = await _controller.updatePassword(_password.text);
    } else {
      if (_code.text.length != CodeField.length) {
        setState(() => _codeError = l10n.errorAuthInvalidCode);
        return;
      }
      result = await _controller.savePassword(
        email: _email.text,
        code: _code.text,
        password: _password.text,
      );
    }
    if (!mounted) return;
    final (step, error) = result;

    if (error == null) {
      _controller.finish();
      // Com a sessão criada, o roteador segue para os termos ou para Jogos.
      showSnack(context, l10n.authPasswordChanged);
      return;
    }

    final text = errorText(l10n, error.code);
    setState(() {
      _step = step;
      if (step == RecoveryStep.code &&
          error.code == ErrorCode.authInvalidCode) {
        _codeError = text;
      } else if (error.code == ErrorCode.authSamePassword ||
          error.code == ErrorCode.authWeakPassword) {
        _passwordError = text;
      }
    });
    if (_codeError == null && _passwordError == null) {
      showErrorSnack(context, error);
    }
  }

  void _back() {
    switch (_step) {
      case RecoveryStep.email:
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(Routes.login);
        }
      case RecoveryStep.code:
        setState(() {
          _step = RecoveryStep.email;
          _code.clear();
          _codeError = null;
          _passwordError = null;
        });
      case RecoveryStep.password:
        // A sessão já existe: quem sai daqui segue logado com a senha antiga.
        _controller.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(forgotPasswordControllerProvider).isLoading;

    return PopScope(
      canPop: _step == RecoveryStep.email,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: InnerAppBar(title: l10n.authForgotTitle, onBack: _back),
        body: _step == RecoveryStep.email
            ? _emailStep(l10n, busy)
            : _codeStep(l10n, busy),
      ),
    );
  }

  Widget _emailStep(AppLocalizations l10n, bool busy) {
    final theme = Theme.of(context);
    final validators = AccessValidators(l10n);
    return Form(
      key: _emailForm,
      child: FormScrollView(
        content: [
          Text(l10n.authForgotSubtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          LabeledField(
            label: l10n.authEmailLabel,
            controller: _email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            validator: validators.email,
            onFieldSubmitted: (_) {
              if (!busy) _sendCode();
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.authSendCode,
            loading: busy,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _codeStep(AppLocalizations l10n, bool busy) {
    final validators = AccessValidators(l10n);
    final email = _email.text.trim();
    final withCode = _step == RecoveryStep.code;
    return Form(
      key: _passwordForm,
      child: FormScrollView(
        content: [
          if (withCode) ...[
            BoldValueText(message: l10n.authCodeSent(email), value: email),
            const SizedBox(height: 24),
            CodeField(
              controller: _code,
              enabled: !busy,
              autofocus: true,
              errorText: _codeError,
              onCompleted: (_) => _codeCompleted(),
            ),
            const SizedBox(height: 24),
          ],
          PasswordField(
            label: l10n.authNewPasswordLabel,
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !busy,
            newPassword: true,
            forceErrorText: _passwordError,
            validator: validators.newPassword,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            onFieldSubmitted: (_) {
              if (!busy) _save();
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.authSaveNewPassword,
            loading: busy,
            onPressed: _save,
          ),
          if (withCode) ...[
            const SizedBox(height: 16),
            ResendCodeButton(onResend: () => _controller.resend(email)),
          ],
        ],
      ),
    );
  }
}
