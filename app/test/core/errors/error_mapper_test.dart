import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/errors/error_mapper.dart';

/// Cenários E01 a E07 de docs/testes-referencia.md, seção 9.4.
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

  test('E04: Edge Function 401 com NOT_AUTHENTICATED vira notAuthenticated', () {
    final exception = FunctionException(
      status: 401,
      details: {
        'error': {'code': 'NOT_AUTHENTICATED'},
      },
    );
    expect(toAppException(exception).code, ErrorCode.notAuthenticated);
  });

  test('E05: AuthException invalid_credentials vira authInvalidCredentials', () {
    final exception = AuthException('Invalid login credentials', code: 'invalid_credentials');
    expect(toAppException(exception).code, ErrorCode.authInvalidCredentials);
  });

  test('E06: AuthException que a fatia 1 não mapeia vira internalError', () {
    final exception = AuthException('Password is too weak', code: 'weak_password');
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

  test('qualquer outra coisa vira internalError', () {
    expect(toAppException(Exception('?')).code, ErrorCode.internalError);
  });

  test('guard converte a exceção da chamada', () async {
    await expectLater(
      guard<void>(() async => throw const SocketException('sem rota')),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', ErrorCode.noConnection),
      ),
    );
  });
}
