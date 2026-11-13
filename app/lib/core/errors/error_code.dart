/// Códigos de erro que o app conhece.
///
/// São os códigos estáveis de docs/contratos-api.md (seção 2) que o app já usa,
/// mais os de autenticação e o de falta de conexão. O enum cresce a cada fatia,
/// junto com os textos de docs/copy.md (seção 5.5).
enum ErrorCode {
  // Gerais (contratos-api.md, seção 2)
  notAuthenticated,
  notFound,
  invalidInput,
  internalError,

  // Só do app
  noConnection,

  // Supabase Auth (docs/copy.md, seção 5.5)
  authInvalidCredentials,
  authEmailNotConfirmed,
  authRateLimited,

  // Supabase Auth da fatia 2 (docs/copy.md, 6.8)
  authWeakPassword,
  authInvalidCode,
  authInvalidEmail,
  authEmailInUse,
  authSamePassword,
  authEmailRateLimited,

  // Google, só do app (docs/copy.md, 6.8)
  authGoogleFailed,

  // Banco e Storage (docs/copy.md, 6.8)
  pixKeyInUse,
  photoTooLarge,
  photoInvalidType,
}

/// Único tipo de exceção que sai da camada `data`.
class AppException implements Exception {
  const AppException(this.code);

  final ErrorCode code;

  @override
  String toString() => 'AppException(${code.name})';
}
