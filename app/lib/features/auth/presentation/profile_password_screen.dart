import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import 'access_validators.dart';
import 'profile_password_controller.dart' as controller;

/// Trocar senha (docs/ui/telas.md, 5.11; profilePassword.png).
class ProfilePasswordScreen extends ConsumerStatefulWidget {
  const ProfilePasswordScreen({super.key});

  @override
  ConsumerState<ProfilePasswordScreen> createState() =>
      _ProfilePasswordScreenState();
}

class _ProfilePasswordScreenState extends ConsumerState<ProfilePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _currentError;
  String? _nextError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _currentError = null;
      _nextError = null;
    });
    await afterServerErrorCleared();
    if (!mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(controller.profilePasswordControllerProvider.notifier)
        .change(current: _current.text, next: _next.text);
    if (!mounted) return;
    if (failure == null) {
      showSnack(context, l10n.authPasswordChanged);
      context.pop();
      return;
    }
    final (field, error) = failure;
    if (field == controller.PasswordField.current &&
        error.code == ErrorCode.authInvalidCredentials) {
      // Texto próprio, no lugar de "E-mail ou senha incorretos" (copy.md, 6.7).
      setState(() => _currentError = l10n.passwordCurrentWrong);
    } else if (field == controller.PasswordField.next &&
        (error.code == ErrorCode.authSamePassword ||
            error.code == ErrorCode.authWeakPassword)) {
      setState(() => _nextError = errorText(l10n, error.code));
    } else {
      showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final validators = AccessValidators(l10n);
    final busy = ref
        .watch(controller.profilePasswordControllerProvider)
        .isLoading;
    return Scaffold(
      appBar: InnerAppBar(title: l10n.profileChangePassword),
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: FormScrollView(
            content: [
              PasswordField(
                label: l10n.passwordCurrentLabel,
                controller: _current,
                enabled: !busy,
                textInputAction: TextInputAction.next,
                forceErrorText: _currentError,
                validator: validators.currentPassword,
                onChanged: (_) {
                  if (_currentError != null) {
                    setState(() => _currentError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                label: l10n.authNewPasswordLabel,
                controller: _next,
                enabled: !busy,
                newPassword: true,
                forceErrorText: _nextError,
                validator: validators.newPassword,
                onChanged: (_) {
                  if (_nextError != null) setState(() => _nextError = null);
                },
                onFieldSubmitted: (_) {
                  if (!busy) _save();
                },
              ),
            ],
            footer: [
              PrimaryButton(
                label: l10n.commonSave,
                loading: busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
