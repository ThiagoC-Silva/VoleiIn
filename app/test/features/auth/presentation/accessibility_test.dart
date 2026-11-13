import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/presentation/auth_providers.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Lista de acessibilidade de docs/ui/design-system.md, seção 8 (RNF05), nas
/// telas da seção 5 do docs/ui/telas.md. A fonte em 150% é o S16
/// (text_scale_test.dart). Aqui, com as diretrizes do flutter_test:
/// - área de toque de 48 x 48 dp;
/// - todo alvo de toque com rótulo para o TalkBack;
/// - contraste de 4,5:1 no texto.
/// Status com texto não se aplica: a fatia 2 não mostra status.
void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  Future<void> open(
    WidgetTester tester,
    String location, {
    String? under,
  }) async {
    await h.pumpApp(tester, location: under);
    if (under == null) {
      await h.go(tester, location);
    } else {
      await h.push(tester, location);
    }
    expect(h.location, location);
  }

  Future<void> meetsChecklist(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  void pendingSignup() => h.container
      .read(accessDraftProvider.notifier)
      .save(
        name: 'Ana Souza',
        email: 'ana@exemplo.com',
        password: 'voleiin123',
      );

  void fullProfile() {
    h.signedIn();
    h.ownProfile(
      name: 'Ana Souza',
      nickname: 'Aninha',
      phone: '+5586999991234',
      phoneVisible: true,
      pixKeyType: PixKeyType.cpf,
      pixKey: '52998224725',
    );
  }

  testWidgets('login', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, '/login');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('cadastro', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, '/signup');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('confirmar e-mail', (tester) async {
    final semantics = tester.ensureSemantics();
    pendingSignup();
    await open(tester, '/confirm-email');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('recuperar senha, etapas 1 e 2', (tester) async {
    final semantics = tester.ensureSemantics();
    when(() => h.auth.sendPasswordRecovery(any())).thenAnswer((_) async {});
    await open(tester, '/forgot-password');
    await meetsChecklist(tester);

    await tester.enterText(find.byType(TextFormField), 'ana@exemplo.com');
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('aceite dos termos', (tester) async {
    final semantics = tester.ensureSemantics();
    h.signedIn();
    h.termsAccepted(accepted: null);
    await open(tester, '/terms');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('texto de um documento', (tester) async {
    final semantics = tester.ensureSemantics();
    h.signedIn();
    h.termsAccepted(accepted: null);
    await open(tester, '/terms/terms_of_use', under: '/terms');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('meu perfil', (tester) async {
    final semantics = tester.ensureSemantics();
    fullProfile();
    await open(tester, '/profile');
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('editar perfil e a sheet da foto', (tester) async {
    final semantics = tester.ensureSemantics();
    fullProfile();
    await open(tester, '/profile/edit', under: '/profile');
    await meetsChecklist(tester);

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('chave Pix, o menu do tipo e a confirmação de remoção', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    fullProfile();
    await open(tester, '/profile/pix', under: '/profile');
    await meetsChecklist(tester);

    await tester.tap(find.byKey(const Key('pixTypeSelector')));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
    await tester.tap(find.text(l10nPt.pixTypeCpf).last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(l10nPt.pixRemove));
    await tester.tap(find.text(l10nPt.pixRemove));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('trocar e-mail, etapas 1 e 2', (tester) async {
    final semantics = tester.ensureSemantics();
    fullProfile();
    when(() => h.auth.requestEmailChange(any())).thenAnswer((_) async {});
    await open(tester, '/profile/email', under: '/profile');
    await meetsChecklist(tester);

    await tester.enterText(find.byType(TextFormField), 'novo@exemplo.com');
    await tester.tap(buttonWithText<FilledButton>(l10nPt.authSendCode));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('trocar senha', (tester) async {
    final semantics = tester.ensureSemantics();
    fullProfile();
    await open(tester, '/profile/password', under: '/profile');
    await meetsChecklist(tester);
    semantics.dispose();
  });
}
