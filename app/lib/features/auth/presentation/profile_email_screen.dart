import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/bold_value_text.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../../../shared/widgets/snack.dart';
import '../data/auth_repository.dart';
import 'access_validators.dart';
import 'profile_email_controller.dart';

/// Trocar e-mail (docs/ui/telas.md, 5.10; profileEmail-etapa1.png e
/// profileEmail-etapa2.png). Duas etapas na mesma rota.
class ProfileEmailScreen extends ConsumerStatefulWidget {
  const ProfileEmailScreen({super.key});

  @override
  ConsumerState<ProfileEmailScreen> createState() => _ProfileEmailScreenState();
}

class _ProfileEmailScreenState extends ConsumerState<ProfileEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  String? _emailError;
  String? _codeError;

  ProfileEmailController get _controller =>
      ref.read(profileEmailControllerProvider.notifier);

  String get _newEmail => _email.text.trim();

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Erros do Auth que dizem respeito ao endereço digitado ficam no campo.
  static const _fieldErrors = {
    ErrorCode.authEmailInUse,
    ErrorCode.authInvalidEmail,
  };

  Future<void> _sendCode() async {
    setState(() => _emailError = null);
    await afterServerErrorCleared();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final error = await _controller.sendCode(_newEmail);
    if (!mounted) return;
    if (error == null) {
      setState(() => _codeStep = true);
    } else if (_fieldErrors.contains(error.code)) {
      setState(() => _emailError = errorText(l10n, error.code));
    } else {
      showErrorSnack(context, error);
    }
  }

  Future<void> _confirm() async {
    if (_code.text.length != CodeField.length) return;
    final l10n = AppLocalizations.of(context);
    final error = await _controller.confirm(
      newEmail: _newEmail,
      code: _code.text,
    );
    if (!mounted) return;
    if (error == null) {
      showSnack(context, l10n.emailChanged);
      context.pop();
    } else if (error.code == ErrorCode.authInvalidCode) {
      // O e-mail atual continua valendo.
      _code.clear();
      setState(() => _codeError = errorText(l10n, error.code));
    } else {
      showErrorSnack(context, error);
    }
  }

  void _back() {
    if (_codeStep) {
      setState(() {
        _codeStep = false;
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
    final busy = ref.watch(profileEmailControllerProvider).isLoading;
    return PopScope(
      canPop: !_codeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: InnerAppBar(title: l10n.profileChangeEmail, onBack: _back),
        body: _codeStep ? _codeContent(l10n, busy) : _emailContent(l10n, busy),
      ),
    );
  }

  Widget _emailContent(AppLocalizations l10n, bool busy) {
    final current = ref.watch(authRepositoryProvider).currentEmail ?? '';
    final validators = AccessValidators(l10n);
    return Form(
      key: _formKey,
      child: FormScrollView(
        content: [
          BoldValueText(
            message: l10n.emailCurrent(current),
            value: current,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          LabeledField(
            label: l10n.emailNewLabel,
            controller: _email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            helperText: l10n.emailKeepsWorking,
            forceErrorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            onFieldSubmitted: (_) {
              if (!busy) _sendCode();
            },
            validator: (value) {
              final required = validators.email(value);
              if (required != null) return required;
              return value!.trim().toLowerCase() == current.toLowerCase()
                  ? l10n.emailSameAsCurrent
                  : null;
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

  Widget _codeContent(AppLocalizations l10n, bool busy) {
    return FormScrollView(
      content: [
        BoldValueText(message: l10n.authCodeSent(_newEmail), value: _newEmail),
        const SizedBox(height: 24),
        CodeField(
          controller: _code,
          enabled: !busy,
          autofocus: true,
          errorText: _codeError,
          onCompleted: (_) => _confirm(),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: _code,
          builder: (context, _) => PrimaryButton(
            label: l10n.authConfirmButton,
            loading: busy,
            onPressed: _code.text.length == CodeField.length ? _confirm : null,
          ),
        ),
        const SizedBox(height: 16),
        ResendCodeButton(onResend: () => _controller.resend(_newEmail)),
      ],
    );
  }
}
