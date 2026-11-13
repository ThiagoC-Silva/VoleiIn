import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/presentation/auth_providers.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S16 de docs/testes-referencia.md, seção 10.4: todas as telas da
/// seção 5 do docs/ui/telas.md com a fonte do sistema em 150%, num celular
/// pequeno (360 x 640 dp), sem overflow (RNF05).
void main() {
  late TestHarness h;
  const small = Size(360, 640);

  setUp(() => h = TestHarness());

  Future<void> open(
    WidgetTester tester,
    String location, {
    String? under,
  }) async {
    await h.pumpApp(tester, textScale: 1.5, size: small, location: under);
    if (under == null) {
      await h.go(tester, location);
    } else {
      await h.push(tester, location);
    }
    expect(h.location, location);
    expect(tester.takeException(), isNull, reason: location);
  }

  void pendingSignup() => h.container
      .read(accessDraftProvider.notifier)
      .save(
        name: 'Ana Souza',
        email: 'ana.souza.de.oliveira@exemplo.com.br',
        password: 'voleiin123',
      );

  void fullProfile() {
    h.signedIn(email: 'ana.souza.de.oliveira@exemplo.com.br');
    h.ownProfile(
      name: 'Ana Souza de Oliveira Albuquerque',
      nickname: 'Aninha do vôlei de praia',
      phone: '+5586999991234',
      phoneVisible: true,
      pixKeyType: PixKeyType.cnpj,
      pixKey: '11222333000181',
    );
  }

  testWidgets('S16: login', (tester) async {
    await open(tester, '/login');
  });

  testWidgets('S16: cadastro, com os erros nos campos', (tester) async {
    await open(tester, '/signup');

    await tester.ensureVisible(
      buttonWithText<FilledButton>(l10nPt.authCreateAccountButton),
    );
    await tester.tap(
      buttonWithText<FilledButton>(l10nPt.authCreateAccountButton),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S16: confirmar e-mail', (tester) async {
    pendingSignup();
    await open(tester, '/confirm-email');
  });

  testWidgets('S16: recuperar senha, etapas 1 e 2', (tester) async {
    when(() => h.auth.sendPasswordRecovery(any())).thenAnswer((_) async {});
    await open(tester, '/forgot-password');

    await tester.enterText(
      find.byType(TextFormField),
      'ana.souza.de.oliveira@exemplo.com.br',
    );
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S16: aceite dos termos', (tester) async {
    h.signedIn();
    h.termsAccepted(accepted: null);
    await open(tester, '/terms');
  });

  testWidgets('S16: texto de um documento', (tester) async {
    h.signedIn();
    h.termsAccepted(accepted: null);
    await open(tester, '/terms/terms_of_use', under: '/terms');
  });

  testWidgets('S16: meu perfil', (tester) async {
    fullProfile();
    await open(tester, '/profile');
  });

  testWidgets('S16: editar perfil e a sheet da foto', (tester) async {
    fullProfile();
    await open(tester, '/profile/edit', under: '/profile');

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S16: chave Pix, o menu do tipo e a confirmação de remoção', (
    tester,
  ) async {
    fullProfile();
    await open(tester, '/profile/pix', under: '/profile');

    await tester.tap(find.byKey(const Key('pixTypeSelector')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l10nPt.pixTypeCnpj).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10nPt.pixRemove));
    await tester.tap(find.text(l10nPt.pixRemove));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S16: trocar e-mail, etapas 1 e 2', (tester) async {
    fullProfile();
    when(() => h.auth.requestEmailChange(any())).thenAnswer((_) async {});
    await open(tester, '/profile/email', under: '/profile');

    await tester.enterText(
      find.byType(TextFormField),
      'novo.endereco.bem.comprido@exemplo.com.br',
    );
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S16: trocar senha', (tester) async {
    fullProfile();
    await open(tester, '/profile/password', under: '/profile');
  });
}
