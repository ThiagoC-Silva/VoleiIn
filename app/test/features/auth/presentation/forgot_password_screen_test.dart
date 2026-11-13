import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/forgot_password_screen.dart';
import 'package:voleiin/shared/widgets/code_field.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S08 de docs/testes-referencia.md, seção 10.4.
void main() {
  testWidgets(
    'S08: código válido com senha recusada fica só no campo de senha',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.sendRecoveryCode(any())).thenAnswer((_) async {});
      when(
        () => auth.verifyRecoveryCode(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});
      when(() => auth.updatePassword(any()))
          .thenThrow(const AppException(ErrorCode.authSamePassword));

      await pumpRouterApp(
        tester,
        initialLocation: Routes.forgotPasswordPath,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        screens: {Routes.forgotPassword: (_) => const ForgotPasswordScreen()},
      );

      // Etapa 1.
      await tester.enterText(find.byType(TextFormField), 'bruno@voleiin.test');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, l10nPt.authSendCode),
      );
      await tester.pumpAndSettle();
      verify(() => auth.sendRecoveryCode('bruno@voleiin.test')).called(1);

      // Etapa 2.
      expect(
        find.widgetWithText(FilledButton, l10nPt.authSaveNewPassword),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.enterText(find.byType(TextFormField).last, 'mesmasenha');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, l10nPt.authSaveNewPassword),
      );
      await tester.pumpAndSettle();

      verify(
        () => auth.verifyRecoveryCode(
          email: 'bruno@voleiin.test',
          code: '123456',
        ),
      ).called(1);
      expect(find.text(l10nPt.errorAuthSamePassword), findsOneWidget);
      // Só o campo de senha continua: o código já valeu e criou a sessão.
      expect(find.byType(CodeField), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'outrasenha');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, l10nPt.authSaveNewPassword),
      );
      await tester.pumpAndSettle();

      verify(() => auth.updatePassword('outrasenha')).called(1);
      verifyNever(
        () => auth.verifyRecoveryCode(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      );
    },
  );
}
