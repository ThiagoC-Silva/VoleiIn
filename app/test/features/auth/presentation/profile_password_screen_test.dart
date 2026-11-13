import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/profile_password_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S15 de docs/testes-referencia.md, seção 10.4 (RF107).
void main() {
  testWidgets('S15: senha atual errada dá erro no campo e não troca a senha', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.reauthenticate(any()))
        .thenThrow(const AppException(ErrorCode.authInvalidCredentials));

    await pumpRouterApp(
      tester,
      initialLocation: Routes.profilePasswordPath,
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      screens: {Routes.profilePassword: (_) => const ProfilePasswordScreen()},
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'errada123');
    await tester.enterText(fields.at(1), 'novasenha1');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10nPt.commonSave),
    );
    await tester.pumpAndSettle();

    verify(() => auth.reauthenticate('errada123')).called(1);
    expect(find.text(l10nPt.passwordCurrentWrong), findsOneWidget);
    expect(find.text(l10nPt.errorAuthInvalidCredentials), findsNothing);
    verifyNever(() => auth.updatePassword(any()));
  });
}
