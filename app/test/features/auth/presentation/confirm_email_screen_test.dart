import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/features/auth/presentation/pending_email_provider.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenários S03, S04 e S05 de docs/testes-referencia.md, seção 10.4.
void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.resendSignupCode(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, {String? email = 'ana@exemplo.com'}) =>
      pumpRouterApp(
        tester,
        initialLocation: Routes.confirmEmailPath,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        setUp: (container) =>
            container.read(pendingEmailProvider.notifier).set(email),
        screens: {Routes.confirmEmail: (_) => const ConfirmEmailScreen()},
      );

  testWidgets(
    'S03: o sexto dígito confirma sozinho; código errado limpa o campo',
    (tester) async {
      when(
        () => auth.verifySignupCode(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      ).thenThrow(const AppException(ErrorCode.authInvalidCode));
      await pump(tester);

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      verify(
        () => auth.verifySignupCode(email: 'ana@exemplo.com', code: '123456'),
      ).called(1);
      expect(find.text(l10nPt.errorAuthInvalidCode), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    },
  );

  testWidgets('S04: Reenviar código fica desabilitado por 60 s', (
    tester,
  ) async {
    await pump(tester);

    final waiting = find.widgetWithText(
      TextButton,
      l10nPt.authResendCodeIn('60'),
    );
    expect(waiting, findsOneWidget);
    expect(tester.widget<TextButton>(waiting).onPressed, isNull);

    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    final ready = find.widgetWithText(TextButton, l10nPt.authResendCode);
    expect(ready, findsOneWidget);
    expect(tester.widget<TextButton>(ready).onPressed, isNotNull);
  });

  testWidgets('S05: sem e-mail em memória, vai para o login', (tester) async {
    await pump(tester, email: null);

    expect(find.byType(ConfirmEmailScreen), findsNothing);
    expect(find.text(stubText(Routes.login)), findsOneWidget);
  });
}
