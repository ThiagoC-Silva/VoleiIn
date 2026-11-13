import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/google_auth_client.dart';

class MockGoogleAuthClient extends Mock implements GoogleAuthClient {}

/// Cenário E12 de docs/testes-referencia.md, seção 10.4.
void main() {
  late MockGoogleAuthClient google;
  late AuthRepository repository;

  setUp(() {
    google = MockGoogleAuthClient();
    // Cliente sem rede: os testes não chegam a chamar o Supabase.
    repository = AuthRepository(
      SupabaseClient('http://127.0.0.1:1', 'chave-de-teste'),
      google,
    );
  });

  test('E12: seletor do Google fechado não é erro', () async {
    when(() => google.fetchIdToken()).thenAnswer((_) async => null);
    expect(await repository.signInWithGoogle(), isFalse);
  });

  test('falha do Google vira authGoogleFailed', () async {
    when(() => google.fetchIdToken()).thenThrow(Exception('DEVELOPER_ERROR'));
    expect(
      repository.signInWithGoogle(),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          ErrorCode.authGoogleFailed,
        ),
      ),
    );
  });
}
