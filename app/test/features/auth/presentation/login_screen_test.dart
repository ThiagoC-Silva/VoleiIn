import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/features/auth/presentation/login_screen.dart';

import '../../../helpers/harness.dart' hide MockAuthRepository;
import '../../../helpers/test_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Cenários L01 a L04 de docs/testes-referencia.md, seção 9.4, e S06 e S07 da
/// seção 10.4 (docs/ui/telas.md, 5.1).
void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.hasSession).thenReturn(false);
  });

  Future<void> pumpLogin(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: TestApp(textScale: textScale, child: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('os campos aceitam digitação já no primeiro quadro', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const TestApp(child: LoginScreen()),
      ),
    );

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isNot(isFalse));
    }
  });

  void mockSignInError(ErrorCode code) {
    when(
      () => repository.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AppException(code));
  }

  testWidgets('L01: campos vazios mostram erro e não chamam o servidor', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authEmailRequired), findsOneWidget);
    expect(find.text(l10nPt.authPasswordRequired), findsOneWidget);
    verifyNever(
      () => repository.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets(
    'L02: senha incorreta mostra o texto do erro e mantém o que foi digitado',
    (tester) async {
      mockSignInError(ErrorCode.authInvalidCredentials);
      await pumpLogin(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ana@voleiin.test');
      await tester.enterText(fields.at(1), 'errada');
      await tester.tap(
        find.widgetWithText(FilledButton, l10nPt.authLoginButton),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.errorAuthInvalidCredentials), findsOneWidget);
      expect(find.text('ana@voleiin.test'), findsOneWidget);
      expect(find.text('errada'), findsOneWidget);
    },
  );

  testWidgets('L03: sem conexão mostra o texto de sem conexão', (tester) async {
    mockSignInError(ErrorCode.noConnection);
    await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@voleiin.test');
    await tester.enterText(fields.at(1), 'voleiin123');
    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);
  });

  testWidgets('L04: login com a fonte do sistema em 150% não estoura', (
    tester,
  ) async {
    await pumpLogin(tester, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.text(l10nPt.authLoginButton), findsOneWidget);
  });

  group('fatia 2', () {
    late TestHarness h;

    setUp(() => h = TestHarness());

    Future<void> typeCredentials(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ana@voleiin.test');
      await tester.enterText(fields.at(1), 'voleiin123');
    }

    testWidgets(
      'S06: e-mail não confirmado oferece Confirmar, que reenvia o código e abre a confirmação',
      (tester) async {
        when(
          () => h.auth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(const AppException(ErrorCode.authEmailNotConfirmed));
        when(() => h.auth.resendSignupCode(any())).thenAnswer((_) async {});
        await h.pumpApp(tester);

        await typeCredentials(tester);
        await tester.tap(buttonWithText<FilledButton>(l10nPt.authLoginButton));
        await tester.pumpAndSettle();

        expect(find.text(l10nPt.errorAuthEmailNotConfirmed), findsOneWidget);

        await tester.tap(
          find.widgetWithText(SnackBarAction, l10nPt.authConfirmAction),
        );
        await tester.pumpAndSettle();

        verify(() => h.auth.resendSignupCode('ana@voleiin.test')).called(1);
        expect(find.byType(ConfirmEmailScreen), findsOneWidget);
        expect(
          find.text(
            l10nPt.authCodeSent('ana@voleiin.test'),
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('S07: fechar o seletor do Google não mostra nada', (
      tester,
    ) async {
      when(() => h.auth.signInWithGoogle()).thenAnswer((_) async => false);
      await h.pumpApp(tester);

      await tester.tap(find.text(l10nPt.authContinueWithGoogle));
      await tester.pumpAndSettle();

      verify(() => h.auth.signInWithGoogle()).called(1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('S07: falha do Google mostra o aviso próprio', (tester) async {
      when(() => h.auth.signInWithGoogle())
          .thenThrow(const AppException(ErrorCode.authGoogleFailed));
      await h.pumpApp(tester);

      await tester.tap(find.text(l10nPt.authContinueWithGoogle));
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.errorAuthGoogleFailed), findsOneWidget);
    });

    testWidgets('o login traz os caminhos para o cadastro e a recuperação', (
      tester,
    ) async {
      await h.pumpApp(tester);

      expect(find.text(l10nPt.authForgotPassword), findsOneWidget);
      expect(find.text(l10nPt.authOr), findsOneWidget);
      expect(find.text(l10nPt.authNoAccount), findsOneWidget);

      await tester.tap(find.text(l10nPt.authCreateAccount));
      await tester.pumpAndSettle();
      expect(h.location, '/signup');
    });

    testWidgets('Esqueci minha senha leva o e-mail digitado', (tester) async {
      await h.pumpApp(tester);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'ana@voleiin.test',
      );
      await tester.tap(find.text(l10nPt.authForgotPassword));
      await tester.pumpAndSettle();

      expect(h.location, '/forgot-password');
      expect(find.text('ana@voleiin.test'), findsOneWidget);
    });
  });
}
