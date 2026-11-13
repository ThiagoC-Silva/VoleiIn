import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/nav_row.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../data/terms_repository.dart';
import '../domain/terms.dart';
import 'legal_document_labels.dart';
import 'terms_providers.dart';

final _acceptProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Aceite dos Termos de Uso e da Política de Privacidade na versão vigente
/// (RF105; docs/ui/telas.md, 5.5; terms.png). Sem barra inferior e sem voltar:
/// o voltar do Android fecha o app.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _checked = false;

  Future<void> _accept(TermsStatus status) async {
    final ok = await ref
        .read(_acceptProvider.notifier)
        .run(() => ref.read(termsRepositoryProvider).accept(status.missing));
    if (!mounted) return;
    if (ok) {
      // A conferência é refeita, e o roteador leva à aba Jogos.
      ref.invalidate(termsStatusProvider);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = ref.read(_acceptProvider).error!;
    // A versão pode ter mudado entre abrir a tela e aceitar: o RLS recusa. O
    // app relê as versões e, se mudaram, mostra a tela de novo, desmarcada.
    try {
      final fresh = await ref.refresh(termsStatusProvider.future);
      if (!mounted) return;
      if (fresh != null && !listEquals(fresh.missing, status.missing)) {
        setState(() => _checked = false);
        return;
      }
    } catch (_) {
      // Sem conexão para reler: vale o aviso do erro original.
    }
    messenger.showSnackBar(SnackBar(content: Text(errorTextFor(l10n, error))));
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorTextFor(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = ref.watch(termsStatusProvider);
    final status = terms.value;

    Widget body;
    if (terms.hasError && !terms.isLoading) {
      body = ErrorStateView(
        error: terms.error!,
        onRetry: () => ref.invalidate(termsStatusProvider),
      );
    } else if (status == null) {
      body = const LoadingState();
    } else {
      body = _content(status);
    }
    return Scaffold(body: SafeArea(child: body));
  }

  Widget _content(TermsStatus status) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accepting = ref.watch(_acceptProvider).isLoading;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccessHeader(
                  icon: Symbols.verified_user,
                  title: Text(l10n.termsTitle),
                  subtitle: Text(
                    status.hadPreviousAcceptance
                        ? l10n.termsSubtitleUpdated
                        : l10n.termsSubtitleFirst,
                  ),
                ),
                const SizedBox(height: 24),
                NavRowGroup(
                  children: [
                    for (final version in status.current)
                      NavRow(
                        icon: version.document.icon,
                        title: version.document.label(l10n),
                        subtitle: l10n.termsVersion(version.version),
                        onTap: () => context.pushNamed(
                          Routes.termsDocument,
                          pathParameters: {
                            'document': version.document.dbValue,
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: accepting
                      ? null
                      : () => setState(() => _checked = !_checked),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _checked,
                          onChanged: accepting
                              ? null
                              : (value) =>
                                    setState(() => _checked = value ?? false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.termsCheckbox,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: l10n.termsAcceptButton,
                loading: accepting,
                onPressed: _checked && status.missing.isNotEmpty
                    ? () => _accept(status)
                    : null,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: accepting ? null : _signOut,
                  child: Text(l10n.authLogout),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
