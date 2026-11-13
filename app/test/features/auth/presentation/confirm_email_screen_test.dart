import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/presentation/auth_providers.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/shared/widgets/code_field.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S03 a S05 de docs/testes-referencia.md, seção 10.4
/// (docs/ui/telas.md, 5.3).
void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  /// O cadastro deixa o e-mail do código pendente em memória.
  Future<void> openWithPendingSignup(WidgetTester tester) async {
    h.container
        .read(accessDraftProvider.notifier)
        .save(
          name: 'Ana Souza',
          email: 'ana@exemplo.com',
          password: 'voleiin123',
        );
    await h.pumpApp(tester, location: '/confirm-email');
  }

  String typedCode(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byType(CodeField),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  testWidgets(
    'S03: o sexto dígito confirma sozinho; código errado limpa o campo',
    (tester) async {
      when(
        () => h.auth.confirmSignup(
          email: any(named: 'email'),
          code: any(named: 'code'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AppException(ErrorCode.authInvalidCode));
      await openWithPendingSignup(tester);

      await tester.enterText(find.byType(CodeField), '123456');
      await tester.pumpAndSettle();

      verify(
        () => h.auth.confirmSignup(
          email: 'ana@exemplo.com',
          code: '123456',
          password: 'voleiin123',
        ),
      ).called(1);
      expect(find.text(l10nPt.errorAuthInvalidCode), findsOneWidget);
      expect(typedCode(tester), isEmpty);
      // Erro de campo, não de ação.
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('cinco dígitos não confirmam', (tester) async {
    await openWithPendingSignup(tester);

    await tester.enterText(find.byType(CodeField), '12345');
    await tester.pumpAndSettle();

    verifyNever(
      () => h.auth.confirmSignup(
        email: any(named: 'email'),
        code: any(named: 'code'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets(
    'S04: Reenviar código fica desabilitado por 60 s, com a contagem',
    (tester) async {
      when(() => h.auth.resendSignupCode(any())).thenAnswer((_) async {});
      await openWithPendingSignup(tester);

      expect(find.text(l10nPt.authResendCodeIn(60)), findsOneWidget);
      expect(
        isEnabled<TextButton>(tester, l10nPt.authResendCodeIn(60)),
        isFalse,
      );

      await tester.pump(const Duration(seconds: 15));
      expect(find.text(l10nPt.authResendCodeIn(45)), findsOneWidget);

      await tester.pump(const Duration(seconds: 45));
      expect(find.text(l10nPt.authResendCode), findsOneWidget);
      expect(isEnabled<TextButton>(tester, l10nPt.authResendCode), isTrue);

      // Reenviar pede um código novo e recomeça a contagem.
      await tester.tap(find.text(l10nPt.authResendCode));
      await tester.pump();
      await tester.pump();

      verify(() => h.auth.resendSignupCode('ana@exemplo.com')).called(1);
      expect(find.text(l10nPt.authCodeResent), findsOneWidget);
      expect(find.text(l10nPt.authResendCodeIn(60)), findsOneWidget);
    },
  );

  testWidgets('S05: sem e-mail em memória, a rota volta ao login', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/confirm-email');

    expect(h.location, '/login');
    expect(find.byType(ConfirmEmailScreen), findsNothing);
  });

  testWidgets('a tela mostra o e-mail e a ajuda para quem já tem conta', (
    tester,
  ) async {
    await openWithPendingSignup(tester);

    expect(find.text(l10nPt.authConfirmEmailTitle), findsOneWidget);
    expect(
      find.text(l10nPt.authCodeSent('ana@exemplo.com'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l10nPt.authConfirmEmailHelp), findsOneWidget);
    expect(find.text(l10nPt.authUseAnotherEmail), findsOneWidget);
  });
}
