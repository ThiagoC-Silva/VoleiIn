import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/password_field.dart';
import '../data/auth_repository.dart';
import 'signup_screen.dart' show minPasswordLength;

final _saveProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);

/// Trocar a senha informando a atual (RF107; docs/ui/telas.md, 5.11;
/// profilePassword.png). Só para quem tem acesso por e-mail e senha.
class ProfilePasswordScreen extends ConsumerStatefulWidget {
  const ProfilePasswordScreen({super.key});

  @override
  ConsumerState<ProfilePasswordScreen> createState() =>
      _ProfilePasswordScreenState();
}

class _ProfilePasswordScreenState extends ConsumerState<ProfilePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  String? _currentError;
  String? _newError;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _currentError = null;
      _newError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final auth = ref.read(authRepositoryProvider);
    final controller = ref.read(_saveProvider.notifier);

    // Confere a senha atual entrando de novo com o e-mail da conta.
    var ok = await controller.run(() => auth.reauthenticate(_current.text));
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(_saveProvider).error!;
      if (error is AppException &&
          error.code == ErrorCode.authInvalidCredentials) {
        // Texto próprio, no lugar de "E-mail ou senha incorretos" (copy 6.7).
        setState(() => _currentError = l10n.passwordCurrentWrong);
      } else {
        _snack(errorTextFor(l10n, error));
      }
      return;
    }

    ok = await controller.run(() => auth.updatePassword(_new.text));
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(_saveProvider).error!;
      final code = error is AppException ? error.code : null;
      if (code == ErrorCode.authSamePassword ||
          code == ErrorCode.authWeakPassword) {
        setState(() => _newError = errorTextFor(l10n, error));
      } else {
        _snack(errorTextFor(l10n, error));
      }
      return;
    }

    _snack(l10n.authPasswordChanged);
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.profile);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final saving = ref.watch(_saveProvider).isLoading;

    return InnerScaffold(
      title: l10n.profileChangePassword,
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(l10n.passwordCurrentLabel),
              PasswordField(
                controller: _current,
                enabled: !saving,
                errorText: _currentError,
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').isEmpty ? l10n.authPasswordRequired : null,
              ),
              const SizedBox(height: 16),
              FieldLabel(l10n.authNewPasswordLabel),
              PasswordField(
                controller: _new,
                enabled: !saving,
                newPassword: true,
                errorText: _newError,
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
                label: l10n.commonSave,
                loading: saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
