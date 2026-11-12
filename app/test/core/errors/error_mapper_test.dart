import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/errors/error_mapper.dart';

/// Cenários E01 a E07 de docs/testes-referencia.md, seção 9.4, e E09 a E11 da
/// seção 10.4.
void main() {
  test('E01: P0001 com NOT_FOUND vira notFound', () {
    final exception = PostgrestException(message: 'NOT_FOUND', code: 'P0001');
    expect(toAppException(exception).code, ErrorCode.notFound);
  });

  test('E02: P0001 com código desconhecido vira internalError', () {
    final exception = PostgrestException(message: 'GAME_FULL', code: 'P0001');
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
}
