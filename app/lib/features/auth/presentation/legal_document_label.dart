import '../../../l10n/app_localizations.dart';
import '../domain/legal_document.dart';

/// Rótulo do enum `legal_document` (docs/copy.md, 6.5).
String legalDocumentLabel(AppLocalizations l10n, LegalDocument document) =>
    switch (document) {
      LegalDocument.termsOfUse => l10n.termsDocumentTermsOfUse,
      LegalDocument.privacyPolicy => l10n.termsDocumentPrivacyPolicy,
    };
