import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/presentation/login_screen.dart';

import '../../../helpers/test_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Cenários L01 a L04 de docs/testes-referencia.md, seção 9.4.
void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.hasSession).thenReturn(false);
  });

  Future<void> pumpLogin(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: TestApp(textScale: textScale, child: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  void mockSignInError(ErrorCode code) {
    when(
      () => repository.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AppException(code));
  }

  testWidgets('L01: campos vazios mostram erro e não chamam o servidor',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authEmailRequired), findsOneWidget);
    expect(find.text(l10nPt.authPasswordRequired), findsOneWidget);
    verifyNever(
      () => repository.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('L02: senha incorreta mostra o texto do erro e mantém o que foi digitado',
      (tester) async {
    mockSignInError(ErrorCode.authInvalidCredentials);
    await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@voleiin.test');
    await tester.enterText(fields.at(1), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorAuthInvalidCredentials), findsOneWidget);
    expect(find.text('ana@voleiin.test'), findsOneWidget);
    expect(find.text('errada'), findsOneWidget);
  });

  testWidgets('L03: sem conexão mostra o texto de sem conexão', (tester) async {
    mockSignInError(ErrorCode.noConnection);
    await pumpLogin(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@voleiin.test');
    await tester.enterText(fields.at(1), 'voleiin123');
    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);
  });

  testWidgets('L04: login com a fonte do sistema em 150% não estoura', (tester) async {
    await pumpLogin(tester, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.text(l10nPt.authLoginButton), findsOneWidget);
  });
}
