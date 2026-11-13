import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/terms.dart';
import 'legal_document_labels.dart';

/// Texto de um documento (docs/ui/telas.md, 5.6; termsDocument.png).
///
/// Provisório até os textos jurídicos (plan-docs.md, 6.1): o corpo é uma frase
/// do ARB. `document` é o valor do enum; outro valor mostra "não encontrado".
class TermsDocumentScreen extends StatelessWidget {
  const TermsDocumentScreen({required this.document, super.key});

  final String document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final legal = LegalDocument.fromDbValue(document);
    if (legal == null) {
      return InnerScaffold(
        title: '',
        body: EmptyState(
          icon: Symbols.error_outline,
          title: l10n.errorNotFound,
          body: '',
        ),
      );
    }
    return InnerScaffold(
      title: legal.label(l10n),
      body: Text(l10n.termsPlaceholderBody, style: theme.textTheme.bodyLarge),
    );
  }
}
