import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/shared/widgets/code_field.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S14 de docs/testes-referencia.md, seção 10.4 (docs/ui/telas.md, 5.10).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn(email: 'ana@exemplo.com');
    when(() => h.auth.requestEmailChange(any())).thenAnswer((_) async {});
    when(
      () => h.auth.confirmEmailChange(
        newEmail: any(named: 'newEmail'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/profile');
    await h.push(tester, '/profile/email');
  }

  Future<void> sendCode(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextFormField), email);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
  }

  testWidgets('a etapa 1 mostra o e-mail atual', (tester) async {
    await open(tester);

    expect(
      find.text(l10nPt.emailCurrent('ana@exemplo.com'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l10nPt.emailKeepsWorking), findsOneWidget);
  });

  testWidgets(
    'S14: novo e-mail igual ao atual mostra erro e não chama o servidor',
    (tester) async {
      await open(tester);

      await sendCode(tester, ' Ana@Exemplo.com ');

      expect(find.text(l10nPt.emailSameAsCurrent), findsOneWidget);
      verifyNever(() => h.auth.requestEmailChange(any()));
    },
  );

  testWidgets('S14: e-mail de outra conta mostra o erro no campo', (
    tester,
  ) async {
    when(() => h.auth.requestEmailChange(any()))
        .thenThrow(const AppException(ErrorCode.authEmailInUse));
    await open(tester);

    await sendCode(tester, 'bruno@exemplo.com');

    expect(find.text(l10nPt.errorAuthEmailInUse), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(CodeField), findsNothing);
  });

  testWidgets('código completo confirma a troca e volta ao perfil', (
    tester,
  ) async {
    await open(tester);

    await sendCode(tester, 'novo@exemplo.com');

    verify(() => h.auth.requestEmailChange('novo@exemplo.com')).called(1);
    expect(
      find.text(l10nPt.authCodeSent('novo@exemplo.com'), findRichText: true),
      findsOneWidget,
    );

    h.signedIn(email: 'novo@exemplo.com');
    await tester.enterText(find.byType(CodeField), '123456');
    await tester.pumpAndSettle();

    verify(
      () => h.auth.confirmEmailChange(
        newEmail: 'novo@exemplo.com',
        code: '123456',
      ),
    ).called(1);
    expect(find.text(l10nPt.emailChanged), findsOneWidget);
    expect(h.location, '/profile');
    expect(find.text('novo@exemplo.com'), findsOneWidget);
  });

  testWidgets('código errado mostra o erro no campo, e o e-mail não muda', (
    tester,
  ) async {
    when(
      () => h.auth.confirmEmailChange(
        newEmail: any(named: 'newEmail'),
        code: any(named: 'code'),
      ),
    ).thenThrow(const AppException(ErrorCode.authInvalidCode));
    await open(tester);

    await sendCode(tester, 'novo@exemplo.com');
    await tester.enterText(find.byType(CodeField), '000000');
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorAuthInvalidCode), findsOneWidget);
    expect(h.location, '/profile/email');
  });
}
