import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/errors/error_mapper.dart';

/// Cenários E01 a E07 de docs/testes-referencia.md, seção 9.4, E09 a E11 da
/// seção 10.4 e E13 e E14 da seção 11.6.
void main() {
  test('E01: P0001 com NOT_FOUND vira notFound', () {
    final exception = PostgrestException(message: 'NOT_FOUND', code: 'P0001');
    expect(toAppException(exception).code, ErrorCode.notFound);
  });

  // Um código que o app não conhece. Até a fatia 3 era GAME_FULL, que a
  // fatia 4 passou a conhecer.
  test('E02: P0001 com código desconhecido vira internalError', () {
    final exception = PostgrestException(
      message: 'CODE_THE_APP_DOES_NOT_KNOW',
      code: 'P0001',
    );
    expect(toAppException(exception).code, ErrorCode.internalError);
  });

  test('E03: 42501 vira internalError', () {
    final exception = PostgrestException(
      message: 'permission denied for table profiles',
      code: '42501',
    );
    expect(toAppException(exception).code, ErrorCode.internalError);
  });

  test(
    'E04: Edge Function 401 com NOT_AUTHENTICATED vira notAuthenticated',
    () {
      final exception = FunctionException(
        status: 401,
        details: {
          'error': {'code': 'NOT_AUTHENTICATED'},
        },
      );
      expect(toAppException(exception).code, ErrorCode.notAuthenticated);
    },
  );

  test(
    'E05: AuthException invalid_credentials vira authInvalidCredentials',
    () {
      final exception = AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
      expect(toAppException(exception).code, ErrorCode.authInvalidCredentials);
    },
  );

  test('E06: AuthException que o app não mapeia vira internalError', () {
    final exception = AuthException(
      'Unexpected failure',
      code: 'unexpected_failure',
    );
    expect(toAppException(exception).code, ErrorCode.internalError);
  });

  test('E07: falhas de rede viram noConnection', () {
    expect(
      toAppException(const SocketException('sem rota')).code,
      ErrorCode.noConnection,
    );
    expect(
      toAppException(http.ClientException('conexão encerrada')).code,
      ErrorCode.noConnection,
    );
    expect(
      toAppException(TimeoutException('tempo esgotado')).code,
      ErrorCode.noConnection,
    );
  });

  // Fatia 2 (docs/testes-referencia.md, seção 10.4).
  group('E09: códigos do Supabase Auth da fatia 2 (docs/copy.md, 6.8)', () {
    const expected = {
      'weak_password': ErrorCode.authWeakPassword,
      'otp_expired': ErrorCode.authInvalidCode,
      'email_address_invalid': ErrorCode.authInvalidEmail,
      'validation_failed': ErrorCode.authInvalidEmail,
      'email_exists': ErrorCode.authEmailInUse,
      'user_already_exists': ErrorCode.authEmailInUse,
      'same_password': ErrorCode.authSamePassword,
      'over_email_send_rate_limit': ErrorCode.authEmailRateLimited,
    };

    for (final entry in expected.entries) {
      test('${entry.key} vira ${entry.value.name}', () {
        final exception = AuthException('mensagem do Auth', code: entry.key);
        expect(toAppException(exception).code, entry.value);
      });
    }
  });

  test('E10: P0001 com PIX_KEY_IN_USE vira pixKeyInUse', () {
    final exception = PostgrestException(
      message: 'PIX_KEY_IN_USE',
      code: 'P0001',
    );
    expect(toAppException(exception).code, ErrorCode.pixKeyInUse);
  });

  test('E11: Storage com HTTP 413 vira photoTooLarge', () {
    const exception = StorageException(
      'The object exceeded the maximum allowed size',
      error: 'Payload too large',
      statusCode: '413',
    );
    expect(toAppException(exception).code, ErrorCode.photoTooLarge);
  });

  test('E11: Storage com invalid_mime_type vira photoInvalidType', () {
    const exception = StorageException(
      'mime type image/gif is not supported',
      error: 'invalid_mime_type',
      statusCode: '415',
    );
    expect(toAppException(exception).code, ErrorCode.photoInvalidType);
  });

  test('outra falha do Storage vira internalError', () {
    const exception = StorageException(
      'new row violates row-level security policy',
      error: 'Unauthorized',
      statusCode: '403',
    );
    expect(toAppException(exception).code, ErrorCode.internalError);
  });

  // Bug da fatia 1: sem rede, o Supabase Auth não lança SocketException. Ele
  // embrulha a falha num AuthRetryableFetchException sem status, que caía em
  // "Algo deu errado" no lugar de "Sem conexão" (RNF07).
  test('falha de rede do Supabase Auth vira noConnection', () {
    final exception = AuthRetryableFetchException(
      message: 'ClientException with SocketException: Failed host lookup',
    );
    expect(toAppException(exception).code, ErrorCode.noConnection);
  });

  test('erro 500 do Supabase Auth continua internalError', () {
    final exception = AuthRetryableFetchException(
      message: 'Internal Server Error',
      statusCode: '500',
    );
    expect(toAppException(exception).code, ErrorCode.internalError);
  });

  // Códigos das funções de grupo e da prévia (docs/copy.md, 7.7).
  const groupCodes = {
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
  };

  for (final entry in groupCodes.entries) {
    test('E13: P0001 com ${entry.key} vira ${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }

  // Códigos das funções de jogo da etapa A da fatia 4 (docs/copy.md, 8.8;
  // contratos-api.md, seção 4: create_game, update_game, join_game,
  // join_waitlist e set_slot_limit) e da etapa B (leave_game, remove_participant
  // e leave_waitlist). A etapa C acrescenta os seus.
  const gameCodes = {
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
    // Etapa B: leave_game, remove_participant e leave_waitlist.
    'LIST_LOCKED': ErrorCode.listLocked,
    'NOT_ON_WAITLIST': ErrorCode.notOnWaitlist,
    'NOT_PARTICIPANT': ErrorCode.notParticipant,
    'RECEIVER_LOCKED': ErrorCode.receiverLocked,
  };

  for (final entry in gameCodes.entries) {
    test('E15: P0001 com ${entry.key} vira ${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }

  test('E14: preview-invite 404 com INVITE_INVALID vira inviteInvalid', () {
    final exception = FunctionException(
      status: 404,
      details: {
        'error': {'code': 'INVITE_INVALID'},
      },
    );
    expect(toAppException(exception).code, ErrorCode.inviteInvalid);
  });

  test('qualquer outra coisa vira internalError', () {
    expect(toAppException(Exception('?')).code, ErrorCode.internalError);
  });

  test('guard converte a exceção da chamada', () async {
    await expectLater(
      guard<void>(() async => throw const SocketException('sem rota')),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.noConnection,
        ),
      ),
    );
  });

  // E16 (docs/testes-referencia.md, 12.6): o detail com os game_ids da RN16.
  test('E16: MEMBER_IS_RECEIVER guarda os game_ids do detail', () {
    const exception = PostgrestException(
      message: 'MEMBER_IS_RECEIVER',
      code: 'P0001',
      details: '{"game_ids":["id1","id2"]}',
    );
    final error = toAppException(exception);
    expect(error.code, ErrorCode.memberIsReceiver);
    expect(error.gameIds, ['id1', 'id2']);
  });

  test('E16: o detail já decodificado também vale', () {
    const exception = PostgrestException(
      message: 'MEMBER_IS_ONLY_GAME_ADMIN',
      code: 'P0001',
      details: {
        'game_ids': ['id1'],
      },
    );
    final error = toAppException(exception);
    expect(error.code, ErrorCode.memberIsOnlyGameAdmin);
    expect(error.gameIds, ['id1']);
  });

  const stageCCodes = {
    'ADMIN_MUST_BE_PARTICIPANT': ErrorCode.adminMustBeParticipant,
    'ALREADY_GAME_ADMIN': ErrorCode.alreadyGameAdmin,
    'NOT_GAME_ADMIN_TARGET': ErrorCode.notGameAdminTarget,
    'LAST_GAME_ADMIN': ErrorCode.lastGameAdmin,
    'MEMBER_IS_RECEIVER': ErrorCode.memberIsReceiver,
    'MEMBER_IS_ONLY_GAME_ADMIN': ErrorCode.memberIsOnlyGameAdmin,
  };
  for (final entry in stageCCodes.entries) {
    test('E15 (etapa C): P0001 com ${entry.key} vira ${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }

  // Fatia 5, etapa A: preview_complete_game e complete_game (docs/copy.md,
  // 9.6). As etapas B e C acrescentam os seus.
  const completionCodes = {
    'GAME_NOT_ENDED': ErrorCode.gameNotEnded,
    'ABSENT_NOT_PARTICIPANT': ErrorCode.absentNotParticipant,
    'RECEIVER_CANNOT_BE_ABSENT': ErrorCode.receiverCannotBeAbsent,
  };
  for (final entry in completionCodes.entries) {
    test('E15 (fatia 5, etapa A): P0001 com ${entry.key} vira '
        '${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }

  // Fatia 5, etapa B: waive_penalty (docs/copy.md, 9.6).
  const waiverCodes = {
    'NOT_A_PENALTY': ErrorCode.notAPenalty,
    'CHARGE_NOT_PENDING': ErrorCode.chargeNotPending,
  };
  for (final entry in waiverCodes.entries) {
    test('E15 (fatia 5, etapa B): P0001 com ${entry.key} vira '
        '${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }

  // Fatia 5, etapa C: change_receiver (docs/copy.md, 9.6).
  const receiverCodes = {
    'GAME_CANCELLED': ErrorCode.gameCancelled,
    'RECEIVER_MUST_BE_PARTICIPANT': ErrorCode.receiverMustBeParticipant,
    'RECEIVER_UNCHANGED': ErrorCode.receiverUnchanged,
    'RECEIVER_CHANGE_BLOCKED': ErrorCode.receiverChangeBlocked,
  };
  for (final entry in receiverCodes.entries) {
    test('E15 (fatia 5, etapa C): P0001 com ${entry.key} vira '
        '${entry.value.name}', () {
      final exception = PostgrestException(message: entry.key, code: 'P0001');
      expect(toAppException(exception).code, entry.value);
    });
  }
}
