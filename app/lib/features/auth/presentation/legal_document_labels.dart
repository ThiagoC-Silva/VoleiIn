import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/terms.dart';

/// Rótulo e ícone de cada documento (enum `legal_document`, docs/copy.md 6.5).
extension LegalDocumentLabel on LegalDocument {
  String label(AppLocalizations l10n) => switch (this) {
    LegalDocument.termsOfUse => l10n.termsDocumentTermsOfUse,
    LegalDocument.privacyPolicy => l10n.termsDocumentPrivacyPolicy,
  };

  IconData get icon => switch (this) {
    LegalDocument.termsOfUse => Symbols.description,
    LegalDocument.privacyPolicy => Symbols.shield_person,
  };
}
