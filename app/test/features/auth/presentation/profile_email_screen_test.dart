import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/profile_email_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S14 de docs/testes-referencia.md, seção 10.4 (RF106).
void main() {
  testWidgets('S14: mesmo e-mail e e-mail de outra conta dão erro no campo', (
    tester,
  ) async {
    final auth = MockAuthRepository();
    when(() => auth.currentEmail).thenReturn('ana@voleiin.test');
    when(() => auth.requestEmailChange(any()))
        .thenThrow(const AppException(ErrorCode.authEmailInUse));

    await pumpRouterApp(
      tester,
      initialLocation: Routes.profileEmailPath,
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      screens: {Routes.profileEmail: (_) => const ProfileEmailScreen()},
    );

    final send = find.widgetWithText(FilledButton, l10nPt.authSendCode);
    await tester.enterText(find.byType(TextFormField), 'ana@voleiin.test');
    await tapVisible(tester, send);
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.emailSameAsCurrent), findsOneWidget);
    verifyNever(() => auth.requestEmailChange(any()));

    await tester.enterText(find.byType(TextFormField), 'bruno@voleiin.test');
    await tapVisible(tester, send);
    await tester.pumpAndSettle();
    verify(() => auth.requestEmailChange('bruno@voleiin.test')).called(1);
    expect(find.text(l10nPt.errorAuthEmailInUse), findsOneWidget);
  });
}
