import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/bold_value_text.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/code_field.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/resend_code_button.dart';
import '../../../shared/widgets/snack.dart';
import 'auth_providers.dart';
import 'confirm_email_controller.dart';

/// Confirmar e-mail com o código (docs/ui/telas.md, 5.3; confirmEmail.png).
/// Sem o e-mail em memória, o roteador volta ao login.
class ConfirmEmailScreen extends ConsumerStatefulWidget {
  const ConfirmEmailScreen({super.key});

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  final _code = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _code.addListener(() {
      if (_codeError != null && _code.text.isNotEmpty) {
        setState(() => _codeError = null);
      }
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.length != CodeField.length) return;
    final l10n = AppLocalizations.of(context);
    final error = await ref
        .read(confirmEmailControllerProvider.notifier)
        .confirm(_code.text);
    if (!mounted || error == null) return;
    if (error.code == ErrorCode.authInvalidCode) {
      // Erro no campo, que é limpo para digitar de novo.
      _code.clear();
      setState(() => _codeError = errorText(l10n, error.code));
    } else {
      showErrorSnack(context, error);
    }
  }

  void _useAnotherEmail() => context.pushReplacementNamed(Routes.signup);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = ref.watch(accessDraftProvider)?.email ?? '';
    final busy = ref.watch(confirmEmailControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: FormScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          content: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconSquare(
                icon: Symbols.mark_email_unread,
                size: 56,
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.authConfirmEmailTitle,
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            BoldValueText(message: l10n.authCodeSent(email), value: email),
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
                onPressed: _code.text.length == CodeField.length
                    ? _confirm
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            ResendCodeButton(
              onResend: () =>
                  ref.read(confirmEmailControllerProvider.notifier).resend(),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.authConfirmEmailHelp,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          footer: [
            Center(
              child: TextButton(
                onPressed: busy ? null : _useAnotherEmail,
                child: Text(l10n.authUseAnotherEmail),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
