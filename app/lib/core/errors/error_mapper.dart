import 'dart:async';
import 'dart:convert';
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
        gameIds: _gameIds(error.details),
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

  // Storage: limite de tamanho e tipos do bucket (rls-matriz.md, seção 3).
  if (error is StorageException) {
    if (error.statusCode == '413') {
      return const AppException(ErrorCode.photoTooLarge);
    }
    if (error.error == 'invalid_mime_type') {
      return const AppException(ErrorCode.photoInvalidType);
    }
    return const AppException(ErrorCode.internalError);
  }

  // Sem rede, o Supabase Auth embrulha a falha num AuthRetryableFetchException
  // sem status HTTP. Com status (500, por exemplo), é erro do servidor.
  if (error is AuthRetryableFetchException) {
    return AppException(
      error.statusCode == null
          ? ErrorCode.noConnection
          : ErrorCode.internalError,
    );
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
/// Os `game_ids` do `detail` do erro (contratos-api.md, `leave_group`), que
/// o PostgREST devolve como texto JSON.
List<String> _gameIds(Object? details) {
  Object? decoded = details;
  if (details is String) {
    try {
      decoded = jsonDecode(details);
    } on FormatException {
      return const [];
    }
  }
  if (decoded is Map && decoded['game_ids'] is List) {
    return [for (final id in decoded['game_ids'] as List) '$id'];
  }
  return const [];
}

const Map<String, ErrorCode> _serverCodes = {
  'NOT_AUTHENTICATED': ErrorCode.notAuthenticated,
  'NOT_FOUND': ErrorCode.notFound,
  'INVALID_INPUT': ErrorCode.invalidInput,
  'INTERNAL_ERROR': ErrorCode.internalError,
  // Trigger da RN105 (fatia 2).
  'PIX_KEY_IN_USE': ErrorCode.pixKeyInUse,
  // Funções de grupo e prévia do convite (fatia 3).
  'NOT_A_MEMBER': ErrorCode.notAMember,
  'NOT_GROUP_ADMIN': ErrorCode.notGroupAdmin,
  'INVITE_INVALID': ErrorCode.inviteInvalid,
  'ALREADY_MEMBER': ErrorCode.alreadyMember,
  'JOIN_REQUEST_PENDING': ErrorCode.joinRequestPending,
  'REQUEST_NOT_PENDING': ErrorCode.requestNotPending,
  'TARGET_NOT_MEMBER': ErrorCode.targetNotMember,
  'CANNOT_REMOVE_SELF': ErrorCode.cannotRemoveSelf,
  'LAST_ADMIN': ErrorCode.lastAdmin,
  'GROUP_HAS_ACTIVE_GAMES': ErrorCode.groupHasActiveGames,
  // Funções de jogo da etapa A da fatia 4.
  'NOT_GAME_ADMIN': ErrorCode.notGameAdmin,
  'INVALID_GAME_DATES': ErrorCode.invalidGameDates,
  'START_IN_PAST': ErrorCode.startInPast,
  'RECEIVER_NEEDS_PIX_KEY': ErrorCode.receiverNeedsPixKey,
  'NO_GAME_ACCESS': ErrorCode.noGameAccess,
  'GAME_NOT_OPEN': ErrorCode.gameNotOpen,
  'GAME_FULL': ErrorCode.gameFull,
  'GAME_NOT_FULL': ErrorCode.gameNotFull,
  'GAME_STARTED': ErrorCode.gameStarted,
  'ALREADY_PARTICIPANT': ErrorCode.alreadyParticipant,
  'ALREADY_ON_WAITLIST': ErrorCode.alreadyOnWaitlist,
  'SLOT_LIMIT_BELOW_PARTICIPANTS': ErrorCode.slotLimitBelowParticipants,
  'LIST_LOCKED': ErrorCode.listLocked,
  'NOT_ON_WAITLIST': ErrorCode.notOnWaitlist,
  'NOT_PARTICIPANT': ErrorCode.notParticipant,
  'RECEIVER_LOCKED': ErrorCode.receiverLocked,
  'ADMIN_MUST_BE_PARTICIPANT': ErrorCode.adminMustBeParticipant,
  'ALREADY_GAME_ADMIN': ErrorCode.alreadyGameAdmin,
  'NOT_GAME_ADMIN_TARGET': ErrorCode.notGameAdminTarget,
  'LAST_GAME_ADMIN': ErrorCode.lastGameAdmin,
  'MEMBER_IS_RECEIVER': ErrorCode.memberIsReceiver,
  'MEMBER_IS_ONLY_GAME_ADMIN': ErrorCode.memberIsOnlyGameAdmin,
};

/// Códigos do Supabase Auth (docs/copy.md, seções 5.5 e 6.8).
const Map<String, ErrorCode> _authCodes = {
  'invalid_credentials': ErrorCode.authInvalidCredentials,
  'email_not_confirmed': ErrorCode.authEmailNotConfirmed,
  'over_request_rate_limit': ErrorCode.authRateLimited,
  'weak_password': ErrorCode.authWeakPassword,
  // O Auth usa o mesmo código para o código errado e o vencido.
  'otp_expired': ErrorCode.authInvalidCode,
  'email_address_invalid': ErrorCode.authInvalidEmail,
  'validation_failed': ErrorCode.authInvalidEmail,
  'email_exists': ErrorCode.authEmailInUse,
  'user_already_exists': ErrorCode.authEmailInUse,
  'same_password': ErrorCode.authSamePassword,
  'over_email_send_rate_limit': ErrorCode.authEmailRateLimited,
};
