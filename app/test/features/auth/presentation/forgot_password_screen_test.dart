import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/shared/widgets/code_field.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S08 de docs/testes-referencia.md, seção 10.4 (docs/ui/telas.md, 5.4).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    when(() => h.auth.sendPasswordRecovery(any())).thenAnswer((_) async {});
    when(
      () => h.auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async {});
    when(() => h.auth.updatePassword(any())).thenAnswer((_) async {});
  });

  Future<void> goToStepTwo(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/forgot-password');
    await tester.enterText(find.byType(TextFormField), 'bruno@voleiin.test');
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSaveNewPassword));
    await tester.pumpAndSettle();
  }

  testWidgets('etapa 1: e-mail vazio mostra erro e não chama o servidor', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/forgot-password');

    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authEmailRequired), findsOneWidget);
    verifyNever(() => h.auth.sendPasswordRecovery(any()));
  });

  testWidgets(
    'S08: código aceito e senha recusada deixam só o campo de senha; o novo toque chama só o updateUser',
    (tester) async {
      when(() => h.auth.updatePassword('voleiin123'))
          .thenThrow(const AppException(ErrorCode.authSamePassword));

      await goToStepTwo(tester);

      // Passa à etapa 2.
      verify(() => h.auth.sendPasswordRecovery('bruno@voleiin.test')).called(1);
      expect(find.byType(CodeField), findsOneWidget);
      expect(
        find.text(
          l10nPt.authCodeSent('bruno@voleiin.test'),
          findRichText: true,
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(CodeField), '123456');
      await tester.enterText(find.byType(TextFormField), 'voleiin123');
      await save(tester);

      // O código valeu, mas a senha é a mesma: só o campo de senha, com o erro.
      expect(find.byType(CodeField), findsNothing);
      expect(find.text(l10nPt.errorAuthSamePassword), findsOneWidget);
      expect(find.text(l10nPt.authResendCode), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'outra-senha-1');
      await save(tester);

      verify(
        () => h.auth.verifyRecoveryCode(
          email: 'bruno@voleiin.test',
          code: '123456',
        ),
      ).called(1);
      verify(() => h.auth.updatePassword('voleiin123')).called(1);
      verify(() => h.auth.updatePassword('outra-senha-1')).called(1);
      expect(find.text(l10nPt.authPasswordChanged), findsOneWidget);
    },
  );

  testWidgets('etapa 2: código errado mostra o erro no campo de código', (
    tester,
  ) async {
    when(
      () => h.auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenThrow(const AppException(ErrorCode.authInvalidCode));

    await goToStepTwo(tester);
    await tester.enterText(find.byType(CodeField), '000000');
    await tester.enterText(find.byType(TextFormField), 'voleiin123');
    await save(tester);

    expect(find.text(l10nPt.errorAuthInvalidCode), findsOneWidget);
    expect(find.byType(CodeField), findsOneWidget);
    verifyNever(() => h.auth.updatePassword(any()));
  });

  testWidgets('etapa 2: senha com menos de 8 caracteres não chama o servidor', (
    tester,
  ) async {
    await goToStepTwo(tester);
    await tester.enterText(find.byType(CodeField), '123456');
    await tester.enterText(find.byType(TextFormField), '1234567');
    await save(tester);

    expect(find.text(l10nPt.authPasswordTooShort), findsOneWidget);
    verifyNever(
      () => h.auth.verifyRecoveryCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    );
  });

  testWidgets('etapa 2: o voltar leva de volta à etapa 1', (tester) async {
    await goToStepTwo(tester);

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();

    expect(find.byType(CodeField), findsNothing);
    expect(find.text(l10nPt.authForgotSubtitle), findsOneWidget);
    expect(h.location, '/forgot-password');
  });
}
