import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/features/auth/presentation/signup_screen.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S01 e S02 de docs/testes-referencia.md, seção 10.4
/// (docs/ui/telas.md, 5.2).
void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  void verifyNoSignUp() => verifyNever(
    () => h.auth.signUp(
      name: any(named: 'name'),
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  );

  Future<void> fill(
    WidgetTester tester, {
    required String name,
    required String email,
    required String password,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(
      buttonWithText<FilledButton>(l10nPt.authCreateAccountButton),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S01: campos vazios mostram erro e não chamam o servidor', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/signup');

    await submit(tester);

    expect(find.text(l10nPt.authNameRequired), findsOneWidget);
    expect(find.text(l10nPt.authEmailRequired), findsOneWidget);
    expect(find.text(l10nPt.authPasswordRequired), findsOneWidget);
    verifyNoSignUp();
  });

  testWidgets('S01: senha de 7 caracteres mostra erro no campo', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/signup');

    await fill(
      tester,
      name: 'Ana Souza',
      email: 'ana@exemplo.com',
      password: '1234567',
    );
    await submit(tester);

    expect(find.text(l10nPt.authPasswordTooShort), findsOneWidget);
    verifyNoSignUp();
  });

  testWidgets('nome com mais de 80 caracteres mostra erro no campo', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/signup');

    await fill(
      tester,
      name: 'A' * 81,
      email: 'ana@exemplo.com',
      password: '12345678',
    );
    await submit(tester);

    expect(find.text(l10nPt.authNameTooLong), findsOneWidget);
    verifyNoSignUp();
  });

  testWidgets(
    'S02: cadastro aceito abre a confirmação, e o voltar não retorna',
    (tester) async {
      when(
        () => h.auth.signUp(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      await h.pumpApp(tester, location: '/signup');

      await fill(
        tester,
        name: ' Ana Souza ',
        email: ' ana@exemplo.com ',
        password: 'voleiin123',
      );
      await submit(tester);

      verify(
        () => h.auth.signUp(
          name: 'Ana Souza',
          email: 'ana@exemplo.com',
          password: 'voleiin123',
        ),
      ).called(1);
      expect(find.byType(ConfirmEmailScreen), findsOneWidget);
      expect(
        find.text(l10nPt.authCodeSent('ana@exemplo.com'), findRichText: true),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsNothing);
    },
  );

  testWidgets('erro do servidor vira SnackBar e mantém o que foi digitado', (
    tester,
  ) async {
    when(
      () => h.auth.signUp(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AppException(ErrorCode.authEmailInUse));
    await h.pumpApp(tester, location: '/signup');

    await fill(
      tester,
      name: 'Ana Souza',
      email: 'ana@exemplo.com',
      password: 'voleiin123',
    );
    await submit(tester);

    expect(find.text(l10nPt.errorAuthEmailInUse), findsOneWidget);
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('ana@exemplo.com'), findsOneWidget);
  });
}
