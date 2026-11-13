import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import 'error_code.dart';

/// Conversão única de tudo o que sai do Supabase em [AppException]
/// (docs/arquitetura-app.md, seção 7). A tela nunca lê mensagem do Postgres.
AppException toAppException(Object error) {
  if (error is AppException) return error;

  // Sem rede (RNF07).
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException) {
    return const AppException(ErrorCode.noConnection);
  }

  // Função SQL e trigger de escrita direta: código em `message`, errcode P0001.
  if (error is PostgrestException) {
    if (error.code == 'P0001') {
      return AppException(
        _serverCodes[error.message.trim()] ?? ErrorCode.internalError,
      );
    }
    return const AppException(ErrorCode.internalError);
  }

  // Edge Function: { "error": { "code": ... } } no corpo.
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map) {
      final inner = details['error'];
      if (inner is Map) {
        final code = inner['code'];
        if (code is String) {
          return AppException(
            _serverCodes[code.trim()] ?? ErrorCode.internalError,
          );
        }
      }
    }
    return const AppException(ErrorCode.internalError);
  }

  // Storage: limites do bucket (docs/rls-matriz.md, seção 3; docs/copy.md, 6.8).
  if (error is StorageException) {
    if (error.statusCode == '413') {
      return const AppException(ErrorCode.photoTooLarge);
    }
    if (error.error == 'invalid_mime_type') {
      return const AppException(ErrorCode.photoInvalidType);
    }
    return const AppException(ErrorCode.internalError);
  }

  // Supabase Auth.
  if (error is AuthException) {
    return AppException(_authCodes[error.code] ?? ErrorCode.internalError);
  }

  return const AppException(ErrorCode.internalError);
}

/// Executa a chamada e converte qualquer exceção (docs/arquitetura-app.md, 12).
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error) {
    throw toAppException(error);
  }
}

/// Códigos do servidor (docs/contratos-api.md, seção 2) que esta fatia conhece.
/// Cada fatia acrescenta os seus.
const Map<String, ErrorCode> _serverCodes = {
  'NOT_AUTHENTICATED': ErrorCode.notAuthenticated,
  'NOT_FOUND': ErrorCode.notFound,
  'INVALID_INPUT': ErrorCode.invalidInput,
  'INTERNAL_ERROR': ErrorCode.internalError,
  'PIX_KEY_IN_USE': ErrorCode.pixKeyInUse,
};

/// Códigos do Supabase Auth (docs/copy.md, seções 5.5 e 6.8). O Auth devolve
/// `otp_expired` tanto para código errado quanto para vencido.
const Map<String, ErrorCode> _authCodes = {
  'invalid_credentials': ErrorCode.authInvalidCredentials,
  'email_not_confirmed': ErrorCode.authEmailNotConfirmed,
  'over_request_rate_limit': ErrorCode.authRateLimited,
  'weak_password': ErrorCode.authWeakPassword,
  'otp_expired': ErrorCode.authInvalidCode,
  'email_address_invalid': ErrorCode.authInvalidEmail,
  'email_exists': ErrorCode.authEmailInUse,
  'user_already_exists': ErrorCode.authEmailInUse,
  'same_password': ErrorCode.authSamePassword,
  'over_email_send_rate_limit': ErrorCode.authEmailRateLimited,
};
