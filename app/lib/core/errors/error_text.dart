import '../../l10n/app_localizations.dart';
import 'error_code.dart';

/// Texto de cada [ErrorCode], do `app_pt.arb`.
///
/// O `switch` é exaustivo: código novo sem texto não compila
/// (docs/arquitetura-app.md, seção 7).
String errorText(AppLocalizations l10n, ErrorCode code) {
  return switch (code) {
    ErrorCode.notAuthenticated => l10n.errorNotAuthenticated,
    ErrorCode.notFound => l10n.errorNotFound,
    ErrorCode.invalidInput => l10n.errorInvalidInput,
    ErrorCode.internalError => l10n.errorInternalError,
    ErrorCode.noConnection => l10n.errorNoConnection,
    ErrorCode.authInvalidCredentials => l10n.errorAuthInvalidCredentials,
    ErrorCode.authEmailNotConfirmed => l10n.errorAuthEmailNotConfirmed,
    ErrorCode.authRateLimited => l10n.errorAuthRateLimited,
  };
}

/// Texto de um erro qualquer, já convertido em [AppException].
String errorTextFor(AppLocalizations l10n, Object error) =>
    errorText(l10n, error is AppException ? error.code : ErrorCode.internalError);
