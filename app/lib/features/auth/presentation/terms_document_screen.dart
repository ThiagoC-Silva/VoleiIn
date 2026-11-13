import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/legal_document.dart';
import 'legal_document_label.dart';

/// Texto de um documento (docs/ui/telas.md, 5.6; termsDocument.png).
/// Provisório até os textos jurídicos (plan-docs.md, seção 6.1).
class TermsDocumentScreen extends StatelessWidget {
  const TermsDocumentScreen({required this.document, super.key});

  /// Valor do enum `legal_document`, vindo da rota.
  final String document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final legal = LegalDocument.fromValue(document);

    if (legal == null) {
      return Scaffold(
        appBar: InnerAppBar(title: ''),
        body: EmptyState(
          icon: Symbols.search_off,
          title: l10n.errorNotFound,
          body: '',
        ),
      );
    }

    return Scaffold(
      appBar: InnerAppBar(title: legalDocumentLabel(l10n, legal)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Text(
          l10n.termsPlaceholderBody,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
