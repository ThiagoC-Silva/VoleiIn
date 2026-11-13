import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/domain/pix_key_type.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/presentation/profile_pix_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S13 de docs/testes-referencia.md, seção 10.4 (RN105).
void main() {
  setUpAll(registerFakes);

  late MockProfileRepository profile;

  setUp(() => profile = MockProfileRepository());

  Future<void> pump(WidgetTester tester, OwnProfile data) {
    when(() => profile.fetchOwn()).thenAnswer((_) async => data);
    return pumpRouterApp(
      tester,
      initialLocation: Routes.profilePixPath,
      overrides: [profileRepositoryProvider.overrideWithValue(profile)],
      screens: {Routes.profilePix: (_) => const ProfilePixScreen()},
    );
  }

  Finder keyField() => find.byType(TextFormField);

  testWidgets('S13a: CPF inválido dá erro sem chamar o servidor', (
    tester,
  ) async {
    await pump(tester, ownProfile());

    await tester.enterText(keyField(), '52998224724');
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10nPt.commonSave),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.pixInvalidCpf), findsOneWidget);
    verifyNever(() => profile.savePixKey(any(), any()));
  });

  testWidgets('S13b: trocar de CPF para E-mail limpa o campo', (tester) async {
    await pump(tester, ownProfile());

    await tester.enterText(keyField(), '529.982.247-25');
    await tapVisible(tester, find.text(l10nPt.pixTypeCpf));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text(l10nPt.pixTypeEmail).last);
    await tester.pumpAndSettle();

    expect(tester.widget<TextFormField>(keyField()).controller!.text, '');
    expect(find.text(l10nPt.pixTypeEmail), findsOneWidget);
  });

  testWidgets('S13c: remoção recusada mostra o aviso e a chave continua', (
    tester,
  ) async {
    when(() => profile.removePixKey())
        .thenThrow(const AppException(ErrorCode.pixKeyInUse));
    await pump(
      tester,
      ownProfile(pixKeyType: PixKeyType.cpf, pixKey: '52998224725'),
    );

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, l10nPt.pixRemove),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.pixRemoveTitle), findsOneWidget);
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, l10nPt.pixRemoveConfirm),
    );
    await tester.pumpAndSettle();

    verify(() => profile.removePixKey()).called(1);
    expect(find.text(l10nPt.errorPixKeyInUse), findsOneWidget);
    expect(find.text('529.982.247-25'), findsOneWidget);
  });
}
