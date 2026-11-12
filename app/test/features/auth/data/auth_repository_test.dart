import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/google_id_token_source.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockGoogleIdTokenSource extends Mock implements GoogleIdTokenSource {}

class FakeAuthResponse extends Fake implements AuthResponse {}

class FakeUserResponse extends Fake implements UserResponse {}

/// Cenário E12 de docs/testes-referencia.md, seção 10.4, e os passos do
/// repositório que os contratos descrevem
/// (specs/001-conta-e-perfil/contracts/repositories.md).
void main() {
  late MockGoTrueClient gotrue;
  late MockGoogleIdTokenSource google;
  late AuthRepository repository;

  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
    registerFallbackValue(OtpType.email);
    registerFallbackValue(UserAttributes());
  });

  setUp(() {
    gotrue = MockGoTrueClient();
    google = MockGoogleIdTokenSource();
    repository = AuthRepository(gotrue, google);
  });

  test('E12: seletor do Google fechado não é erro e não chama o servidor', () async {
    when(() => google.idToken()).thenAnswer((_) async => null);

    final signedIn = await repository.signInWithGoogle();

    expect(signedIn, isFalse);
    verifyNever(
      () => gotrue.signInWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
      ),
    );
  });

  test('Google concluído troca o ID token por sessão', () async {
    when(() => google.idToken()).thenAnswer((_) async => 'id-token');
    when(
      () => gotrue.signInWithIdToken(
        provider: any(named: 'provider'),
        idToken: any(named: 'idToken'),
      ),
    ).thenAnswer((_) async => FakeAuthResponse());

    final signedIn = await repository.signInWithGoogle();

    expect(signedIn, isTrue);
    verify(
      () => gotrue.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: 'id-token',
      ),
    ).called(1);
  });

  test('falha do Google vira authGoogleFailed', () async {
    when(
      () => google.idToken(),
    ).thenThrow(const AppException(ErrorCode.authGoogleFailed));

    await expectLater(
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

  group('confirmação do cadastro', () {
    void mockVerify() {
      when(
        () => gotrue.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => FakeAuthResponse());
    }

    test('confere o código e grava de novo a senha digitada', () async {
      mockVerify();
      when(
        () => gotrue.updateUser(any()),
      ).thenAnswer((_) async => FakeUserResponse());

      await repository.confirmSignup(
        email: 'carla@exemplo.com',
        code: '123456',
        password: 'senha-da-carla',
      );

      verifyInOrder([
        () => gotrue.verifyOTP(
          email: 'carla@exemplo.com',
          token: '123456',
          type: OtpType.email,
        ),
        () => gotrue.updateUser(
          any(
            that: isA<UserAttributes>().having(
              (a) => a.password,
              'password',
              'senha-da-carla',
            ),
          ),
        ),
      ]);
    });

    test('a senha já ser a da conta (same_password) não é erro', () async {
      mockVerify();
      when(() => gotrue.updateUser(any())).thenThrow(
        const AuthException('same password', code: 'same_password'),
      );

      await expectLater(
        repository.confirmSignup(
          email: 'carla@exemplo.com',
          code: '123456',
          password: 'senha-da-carla',
        ),
        completes,
      );
    });

    test('código errado não tenta gravar a senha', () async {
      when(
        () => gotrue.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenThrow(const AuthException('expired', code: 'otp_expired'));

      await expectLater(
        repository.confirmSignup(
          email: 'carla@exemplo.com',
          code: '000000',
          password: 'senha-da-carla',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            ErrorCode.authInvalidCode,
          ),
        ),
      );
      verifyNever(() => gotrue.updateUser(any()));
    });
  });

  test('sair encerra também a sessão do Google', () async {
    when(() => gotrue.signOut()).thenAnswer((_) async {});
    when(() => google.signOut()).thenAnswer((_) async {});

    await repository.signOut();

    verifyInOrder([() => gotrue.signOut(), () => google.signOut()]);
  });
}
