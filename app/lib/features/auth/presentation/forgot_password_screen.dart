import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../data/auth_repository.dart';
import 'code_sent_text.dart';
import 'pending_email_provider.dart';
import 'signup_screen.dart' show minPasswordLength;

final _sendProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);
final _saveProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);

/// Recuperar a senha com um código enviado ao e-mail (RF06, ADR 0017;
/// docs/ui/telas.md, 5.4; forgotPassword-etapa1.png e -etapa2.png).
///
/// Duas etapas sem trocar de rota. O código, ao valer, cria a sessão; se a
/// senha nova for recusada depois disso, a tela fica só com o campo de senha.
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

  int _step = 1;

  /// O código já valeu e a sessão existe: falta só a senha nova.
  bool _verified = false;
  String? _codeError;
  String? _passwordError;
  late final RecoveryInProgressNotifier _recovery;

  @override
  void initState() {
    super.initState();
    // Vem do login com o e-mail digitado, se houver (telas.md, 5.1).
    _email = TextEditingController(text: ref.read(pendingEmailProvider));
    _recovery = ref.read(recoveryInProgressProvider.notifier);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    // Saiu da tela: o roteador volta a tratar a sessão normalmente.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recovery.set(false));
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  void _snack(Object error) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorTextFor(l10n, error))));
  }

  Future<void> _sendCode() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final ok = await ref
        .read(_sendProvider.notifier)
        .run(() => _auth.sendRecoveryCode(email));
    if (!mounted) return;
    if (!ok) return _snack(ref.read(_sendProvider).error!);
    // O Auth responde igual para e-mail com e sem conta: o app sempre avança.
    setState(() => _step = 2);
  }

  Future<bool> _resend() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.sendRecoveryCode(_email.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.authCodeResent)));
      return true;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorTextFor(l10n, error))),
      );
      return false;
    }
  }

  void _onCodeCompleted(String code) {
    // O código confirma sozinho; sem senha nova ainda, o foco vai para ela.
    if (_password.text.length >= minPasswordLength) {
      _save();
    } else {
      _passwordFocus.requestFocus();
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_passwordForm.currentState?.validate() ?? false)) return;
    if (!_verified && _code.text.length != CodeField.length) {
      setState(() => _codeError = l10n.errorAuthInvalidCode);
      return;
    }
    if (ref.read(_saveProvider).isLoading) return;
    setState(() => _passwordError = null);

    final email = _email.text.trim();
    final password = _password.text;
    final controller = ref.read(_saveProvider.notifier);

    if (!_verified) {
      _recovery.set(true);
      final ok = await controller.run(
        () => _auth.verifyRecoveryCode(email: email, code: _code.text),
      );
      if (!mounted) return;
      if (!ok) {
        _recovery.set(false);
        final error = ref.read(_saveProvider).error!;
        if (error is AppException && error.code == ErrorCode.authInvalidCode) {
          setState(() => _codeError = errorTextFor(l10n, error));
          _code.clear();
        } else {
          _snack(error);
        }
        return;
      }
      setState(() => _verified = true);
    }

    final ok = await controller.run(() => _auth.updatePassword(password));
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(_saveProvider).error!;
      final code = error is AppException ? error.code : null;
      if (code == ErrorCode.authSamePassword ||
          code == ErrorCode.authWeakPassword) {
        // A sessão já existe: só a senha precisa de outra tentativa.
        setState(() => _passwordError = errorTextFor(l10n, error));
      } else {
        _snack(error);
      }
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.authPasswordChanged)));
    _recovery.set(false);
    ref.read(pendingEmailProvider.notifier).set(null);
    // Logado: o roteador faz a conferência dos termos.
    context.goNamed(Routes.games);
  }

  void _back() {
    if (_step == 2 && !_verified) {
      setState(() {
        _step = 1;
        _code.clear();
        _codeError = null;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: _step == 1 || _verified,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: InnerScaffold(
        title: l10n.authForgotTitle,
        onBack: _back,
        body: _step == 1 ? _stepOne(l10n, theme) : _stepTwo(l10n),
      ),
    );
  }

  Widget _stepOne(AppLocalizations l10n, ThemeData theme) {
    final sending = ref.watch(_sendProvider).isLoading;
    return Form(
      key: _emailForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.authForgotSubtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          FieldLabel(l10n.authEmailLabel),
          TextFormField(
            controller: _email,
            enabled: !sending,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendCode(),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.authEmailRequired : null,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.authSendCode,
            loading: sending,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _stepTwo(AppLocalizations l10n) {
    final saving = ref.watch(_saveProvider).isLoading;
    final email = _email.text.trim();
    return Form(
      key: _passwordForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_verified) ...[
            BoldValueText(text: l10n.authCodeSent(email), value: email),
            const SizedBox(height: 24),
            CodeField(
              controller: _code,
              enabled: !saving,
              errorText: _codeError,
              semanticLabel: l10n.authCodeLabel,
              onCompleted: _onCodeCompleted,
            ),
            const SizedBox(height: 24),
          ],
          FieldLabel(l10n.authNewPasswordLabel),
          PasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !saving,
            newPassword: true,
            errorText: _passwordError,
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            onSubmitted: (_) => _save(),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) return l10n.authPasswordRequired;
              if (password.length < minPasswordLength) {
                return l10n.authPasswordTooShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.authSaveNewPassword,
            loading: saving,
            onPressed: _save,
          ),
          if (!_verified) ...[
            const SizedBox(height: 16),
            ResendCodeButton(onResend: _resend),
          ],
        ],
      ),
    );
  }
}
