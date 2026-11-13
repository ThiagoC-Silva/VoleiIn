import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/features/auth/presentation/signup_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenários S01 e S02 de docs/testes-referencia.md, seção 10.4.
void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.resendSignupCode(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester) => pumpRouterApp(
    tester,
    initialLocation: Routes.signupPath,
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
    screens: {
      Routes.signup: (_) => const SignupScreen(),
      Routes.confirmEmail: (_) => const ConfirmEmailScreen(),
    },
  );

  Finder submit() =>
      find.widgetWithText(FilledButton, l10nPt.authCreateAccountButton);

  testWidgets(
    'S01: campos vazios e senha curta dão erro sem chamar o servidor',
    (tester) async {
      await pump(tester);

      await tapVisible(tester, submit());
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.authNameRequired), findsOneWidget);
      expect(find.text(l10nPt.authEmailRequired), findsOneWidget);
      expect(find.text(l10nPt.authPasswordRequired), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana Souza');
      await tester.enterText(fields.at(1), 'ana@exemplo.com');
      await tester.enterText(fields.at(2), '1234567');
      await tapVisible(tester, submit());
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.authPasswordTooShort), findsOneWidget);

      verifyNever(
        () => auth.signUp(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets(
    'S02: cadastro aceito abre a confirmação e o voltar não volta ao cadastro',
    (tester) async {
      when(
        () => auth.signUp(
          name: any(named: 'name'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      await pump(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ana Souza');
      await tester.enterText(fields.at(1), 'ana@exemplo.com');
      await tester.enterText(fields.at(2), 'senha1234');
      await tapVisible(tester, submit());
      await tester.pumpAndSettle();

      verify(
        () => auth.signUp(
          name: 'Ana Souza',
          email: 'ana@exemplo.com',
          password: 'senha1234',
        ),
      ).called(1);
      expect(find.byType(ConfirmEmailScreen), findsOneWidget);
      expect(
        find.text(l10nPt.authCodeSent('ana@exemplo.com'), findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(SignupScreen), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsNothing);
      expect(find.text(stubText(Routes.login)), findsOneWidget);
    },
  );
}
