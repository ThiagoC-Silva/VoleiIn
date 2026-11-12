import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S15 de docs/testes-referencia.md, seção 10.4 (docs/ui/telas.md, 5.11).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    when(() => h.auth.verifyCurrentPassword(any())).thenAnswer((_) async {});
    when(() => h.auth.updatePassword(any())).thenAnswer((_) async {});
  });

  Future<void> submit(
    WidgetTester tester, {
    required String current,
    required String next,
  }) async {
    await h.pumpApp(tester, location: '/profile');
    await h.push(tester, '/profile/password');
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.commonSave));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'S15: senha atual errada mostra o erro no campo e não troca a senha',
    (tester) async {
      when(
        () => h.auth.verifyCurrentPassword(any()),
      ).thenThrow(const AppException(ErrorCode.authInvalidCredentials));

      await submit(tester, current: 'errada-123', next: 'nova-senha-1');

      verify(() => h.auth.verifyCurrentPassword('errada-123')).called(1);
      expect(find.text(l10nPt.passwordCurrentWrong), findsOneWidget);
      expect(find.text(l10nPt.errorAuthInvalidCredentials), findsNothing);
      verifyNever(() => h.auth.updatePassword(any()));
      expect(h.location, '/profile/password');
    },
  );

  testWidgets('nova senha igual à atual mostra o erro no campo Nova senha', (
    tester,
  ) async {
    when(
      () => h.auth.updatePassword(any()),
    ).thenThrow(const AppException(ErrorCode.authSamePassword));

    await submit(tester, current: 'voleiin123', next: 'voleiin123');

    expect(find.text(l10nPt.errorAuthSamePassword), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('nova senha curta não chama o servidor', (tester) async {
    await submit(tester, current: 'voleiin123', next: '1234567');

    expect(find.text(l10nPt.authPasswordTooShort), findsOneWidget);
    verifyNever(() => h.auth.verifyCurrentPassword(any()));
  });

  testWidgets('troca aceita confere a atual, grava a nova e volta ao perfil', (
    tester,
  ) async {
    await submit(tester, current: 'voleiin123', next: 'nova-senha-1');

    verifyInOrder([
      () => h.auth.verifyCurrentPassword('voleiin123'),
      () => h.auth.updatePassword('nova-senha-1'),
    ]);
    expect(find.text(l10nPt.authPasswordChanged), findsOneWidget);
    expect(h.location, '/profile');
  });
}
