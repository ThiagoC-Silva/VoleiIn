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
import '../../../shared/widgets/resend_code_button.dart';
import '../data/auth_repository.dart';
import 'code_sent_text.dart';
import 'profile_providers.dart';

final _sendProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);
final _verifyProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Trocar o e-mail de acesso com código no endereço novo (RF106, ADR 0017;
/// docs/ui/telas.md, 5.10; profileEmail-etapa1.png e -etapa2.png). Até o
/// código, o e-mail atual continua valendo. Só para quem tem acesso por e-mail e
/// senha: o roteador manda os outros de volta ao perfil.
class ProfileEmailScreen extends ConsumerStatefulWidget {
  const ProfileEmailScreen({super.key});

  @override
  ConsumerState<ProfileEmailScreen> createState() => _ProfileEmailScreenState();
}

class _ProfileEmailScreenState extends ConsumerState<ProfileEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newEmail = TextEditingController();
  final _code = TextEditingController();
  int _step = 1;
  String? _emailError;
  String? _codeError;

  @override
  void dispose() {
    _newEmail.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  String get _email => _newEmail.text.trim();

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    setState(() => _emailError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(_sendProvider.notifier)
        .run(() => _auth.requestEmailChange(_email));
    if (!mounted) return;
    if (ok) return setState(() => _step = 2);

    final error = ref.read(_sendProvider).error!;
    final code = error is AppException ? error.code : null;
    if (code == ErrorCode.authEmailInUse ||
        code == ErrorCode.authInvalidEmail) {
      setState(() => _emailError = errorTextFor(l10n, error));
    } else {
      _snack(errorTextFor(l10n, error));
    }
  }

  Future<bool> _resend() async {
    final l10n = AppLocalizations.of(context);
    try {
      await _auth.requestEmailChange(_email);
      if (mounted) _snack(l10n.authCodeResent);
      return true;
    } catch (error) {
      if (mounted) _snack(errorTextFor(l10n, error));
      return false;
    }
  }

  Future<void> _verify(String code) async {
    if (code.length != CodeField.length) return;
    if (ref.read(_verifyProvider).isLoading) return;
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(_verifyProvider.notifier)
        .run(() => _auth.verifyEmailChange(newEmail: _email, code: code));
    if (!mounted) return;
    if (ok) {
      _snack(l10n.emailChanged);
      ref.invalidate(ownProfileProvider);
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(Routes.profile);
      }
      return;
    }
    final error = ref.read(_verifyProvider).error!;
    if (error is AppException && error.code == ErrorCode.authInvalidCode) {
      // O e-mail atual continua valendo.
      setState(() => _codeError = errorTextFor(l10n, error));
      _code.clear();
    } else {
      _snack(errorTextFor(l10n, error));
    }
  }

  void _back() {
    if (_step == 2) {
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
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: InnerScaffold(
        title: l10n.profileChangeEmail,
        onBack: _back,
        body: _step == 1 ? _stepOne(l10n) : _stepTwo(l10n),
      ),
    );
  }

  Widget _stepOne(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final sending = ref.watch(_sendProvider).isLoading;
    final current = _auth.currentEmail ?? '';
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoldValueText(text: l10n.emailCurrent(current), value: current),
          const SizedBox(height: 24),
          FieldLabel(l10n.emailNewLabel),
          TextFormField(
            controller: _newEmail,
            enabled: !sending,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _send(),
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            decoration: InputDecoration(errorText: _emailError),
            validator: (value) {
              final email = (value ?? '').trim();
              if (email.isEmpty) return l10n.authEmailRequired;
              // Igual ao atual: erro no campo, sem chamar o servidor.
              if (email.toLowerCase() == current.toLowerCase()) {
                return l10n.emailSameAsCurrent;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.emailKeepsWorking,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.authSendCode,
            loading: sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Widget _stepTwo(AppLocalizations l10n) {
    final verifying = ref.watch(_verifyProvider).isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BoldValueText(text: l10n.authCodeSent(_email), value: _email),
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
      ],
    );
  }
}
