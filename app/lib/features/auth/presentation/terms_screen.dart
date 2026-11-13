import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/arrow_rows.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/legal_document.dart';
import '../domain/terms.dart';
import 'auth_providers.dart';
import 'legal_document_label.dart';
import 'terms_controller.dart';

/// Aceite dos termos (docs/ui/telas.md, 5.5; terms.png). Sem barra inferior e
/// sem voltar: o voltar do Android fecha o app. É também a tela dos estados
/// carregando e erro da conferência (research R3).
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _checked = false;

  Future<void> _accept(TermsStatus status) async {
    final controller = ref.read(termsControllerProvider.notifier);
    final result = await controller.accept(status);
    if (!mounted) return;
    switch (result) {
      case TermsAcceptResult.accepted:
        break; // O roteador segue para a aba Jogos.
      case TermsAcceptResult.versionChanged:
        setState(() => _checked = false);
      case TermsAcceptResult.failed:
        if (controller.lastError != null) {
          showErrorSnack(context, controller.lastError!);
        }
    }
  }

  Future<void> _signOut() async {
    final error = await ref.read(termsControllerProvider.notifier).signOut();
    if (mounted && error != null) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(termsStatusProvider);
    return Scaffold(
      body: SafeArea(
        child: status.when(
          loading: () => const LoadingState(),
          error: (error, _) => ErrorStateView(
            error: error,
            onRetry: () => ref.invalidate(termsStatusProvider),
          ),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(TermsStatus status) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(termsControllerProvider).isLoading;

    return FormScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      content: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconSquare(
            icon: Symbols.verified_user,
            size: 56,
            background: theme.colorScheme.primary,
            foreground: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.termsTitle, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 16),
        Text(
          status.hadPreviousAcceptance
              ? l10n.termsSubtitleUpdated
              : l10n.termsSubtitleFirst,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ArrowRowGroup(
          rows: [
            for (final version in status.current)
              ArrowRow(
                icon: version.document == LegalDocument.termsOfUse
                    ? Symbols.description
                    : Symbols.shield_person,
                title: legalDocumentLabel(l10n, version.document),
                subtitle: l10n.termsVersion(version.version),
                onTap: () => context.pushNamed(
                  Routes.termsDocument,
                  pathParameters: {'document': version.document.value},
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : () => setState(() => _checked = !_checked),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _checked,
                onChanged: busy
                    ? null
                    : (value) => setState(() => _checked = value ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.termsCheckbox,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: [
        PrimaryButton(
          label: l10n.termsAcceptButton,
          loading: busy,
          onPressed: _checked ? () => _accept(status) : null,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: busy ? null : _signOut,
            child: Text(l10n.authLogout),
          ),
        ),
      ],
    );
  }
}
