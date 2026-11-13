import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/shared/widgets/code_field.dart';

import '../test/helpers/test_app.dart';
import 'mailpit.dart';

/// Cenários L08 a L11 de docs/testes-referencia.md, seção 10.4.
///
/// Roda no emulador, contra o Supabase local com o seed (docs/setup.md, 8). O
/// código de cada e-mail chega pelo Mailpit. Cada fluxo deixa o seed como
/// encontrou: o L08 usa um e-mail novo, e L09 a L11 devolvem no fim a senha, o
/// apelido, o telefone e o e-mail originais.
///
/// ```bash
/// flutter test integration_test --dart-define-from-file=env/local.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  late Mailpit mailpit;

  GoTrueClient auth() => Supabase.instance.client.auth;

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
    mailpit = Mailpit();
  });

  tearDownAll(() => mailpit.close());

  setUp(() async {
    await auth().signOut();
  });

  /// Abre o app do zero, como depois de fechá-lo.
  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(Container());
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();
  }

  /// Bombeia quadros até o [finder] aparecer: as chamadas ao Supabase local
  /// levam tempo de verdade.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    // Mostra o que está na tela, para o log dizer onde o fluxo parou.
    final onScreen = find
        .byType(Text)
        .evaluate()
        .map(
          (e) =>
              (e.widget as Text).data ??
              (e.widget as Text).textSpan?.toPlainText(),
        )
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .join(' | ');
    throw TestFailure(
      'Não apareceu em ${timeout.inSeconds} s: $finder\nNa tela: $onScreen',
    );
  }

  /// Toca quando o alvo já recebe o toque. Logo depois de trocar de tela, o
  /// widget existe mas ainda está sob a animação da rota, e o toque cai na
  /// tela que sai (visto no emulador de API 29, mais lento).
  Future<void> tapReady(WidgetTester tester, Finder finder) async {
    await pumpUntil(tester, finder);
    await tester.ensureVisible(finder);
    await pumpUntil(tester, finder.hitTestable());
    await tester.tap(finder);
  }

  final gamesTab = find.descendant(
    of: find.byType(AppBar),
    matching: find.text(l10nPt.navGames),
  );
  final loginScreen = find.text(l10nPt.authLoginSubtitle);

  Future<void> fillLogin(WidgetTester tester, String email, String pass) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), pass);
    await tapReady(
      tester,
      find.widgetWithText(FilledButton, l10nPt.authLoginButton),
    );
  }

  Future<void> openProfileTab(WidgetTester tester) async {
    await tapReady(tester, find.text(l10nPt.navProfile).last);
    await pumpUntil(tester, find.text(l10nPt.authLogout));
  }

  Future<void> signOutFromProfile(WidgetTester tester) async {
    await openProfileTab(tester);
    final logout = find.widgetWithText(OutlinedButton, l10nPt.authLogout);
    await tapReady(tester, logout);
    await pumpUntil(tester, loginScreen);
  }

  testWidgets('L08: cria a conta, confirma o código e aceita os termos', (
    tester,
  ) async {
    final email = 'l08-${DateTime.now().millisecondsSinceEpoch}@voleiin.test';
    await openApp(tester);

    await tapReady(tester, find.text(l10nPt.authCreateAccount).last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Carla Souza');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), password);
    final before = await mailpit.snapshot(email);
    final create = find.widgetWithText(
      FilledButton,
      l10nPt.authCreateAccountButton,
    );
    await tapReady(tester, create);
    await pumpUntil(tester, find.byType(CodeField));

    final code = await mailpit.waitForCode(email, before: before);
    // O sexto dígito confirma sozinho.
    await tester.enterText(find.byType(CodeField), code);
    await pumpUntil(tester, find.byType(Checkbox));

    await tapReady(tester, find.byType(Checkbox));
    await tester.pump();
    await tapReady(
      tester,
      find.widgetWithText(FilledButton, l10nPt.termsAcceptButton),
    );
    await pumpUntil(tester, gamesTab);

    await openProfileTab(tester);
    expect(find.text('Carla Souza'), findsOneWidget);
    expect(find.text(email), findsOneWidget);
  });

  testWidgets('L09: recupera a senha com o código e entra com a nova', (
    tester,
  ) async {
    const email = 'bruno@voleiin.test';
    const newPassword = 'nova-senha-l09';
    addTearDown(() async {
      // Devolve a senha do seed.
      await auth().signInWithPassword(email: email, password: newPassword);
      await auth().updateUser(UserAttributes(password: password));
      await auth().signOut();
    });

    await openApp(tester);
    await tapReady(tester, find.text(l10nPt.authForgotPassword));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), email);
    final before = await mailpit.snapshot(email);
    await tapReady(
      tester,
      find.widgetWithText(FilledButton, l10nPt.authSendCode),
    );
    await pumpUntil(tester, find.byType(CodeField));

    final code = await mailpit.waitForCode(email, before: before);
    await tester.enterText(find.byType(TextFormField), newPassword);
    // Com a senha já digitada, o sexto dígito salva sozinho.
    await tester.enterText(find.byType(CodeField), code);
    await pumpUntil(tester, gamesTab);

    // Sai e entra com a senha nova.
    await signOutFromProfile(tester);
    await fillLogin(tester, email, newPassword);
    await pumpUntil(tester, gamesTab);

    // A senha antiga não entra mais.
    await signOutFromProfile(tester);
    await fillLogin(tester, email, password);
    await pumpUntil(tester, find.text(l10nPt.errorAuthInvalidCredentials));
    expect(loginScreen, findsOneWidget);
  });

  testWidgets('L10: muda o apelido e o telefone, e eles ficam ao reabrir', (
    tester,
  ) async {
    addTearDown(() async {
      // Devolve o apelido e o telefone do seed (supabase/seed.sql).
      final client = Supabase.instance.client;
      final uid = auth().currentUser!.id;
      await client.from('profiles').update({'nickname': null}).eq('id', uid);
      await client
          .from('profile_private')
          .update({'phone': '+5586999991234', 'phone_visible': true})
          .eq('user_id', uid);
      await auth().signOut();
    });

    await auth().signInWithPassword(
      email: 'ana@voleiin.test',
      password: password,
    );
    await openApp(tester);
    await openProfileTab(tester);

    await tapReady(tester, find.text(l10nPt.profileEdit));
    await pumpUntil(tester, find.text(l10nPt.profileNicknameLabel));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Aninha');
    await tester.enterText(fields.at(2), '86988887777');
    final save = find.widgetWithText(FilledButton, l10nPt.commonSave);
    await tapReady(tester, save);
    await pumpUntil(tester, find.text(l10nPt.profileSaved));

    // Fecha e reabre o app.
    await openApp(tester);
    await openProfileTab(tester);
    await pumpUntil(tester, find.text('Aninha'));

    // O telefone aparece formatado na edição: a tela Meu perfil não mostra
    // telefone (docs/ui/telas.md, 5.7).
    await tapReady(tester, find.text(l10nPt.profileEdit));
    await pumpUntil(tester, find.text('(86) 98888-7777'));
  });

  testWidgets('L11: troca o e-mail com o código e entra com o novo', (
    tester,
  ) async {
    const oldEmail = 'diego@voleiin.test';
    final newEmail =
        'diego-${DateTime.now().millisecondsSinceEpoch}@voleiin.test';
    addTearDown(() async {
      // Devolve o e-mail do seed, com o código enviado ao endereço antigo.
      await auth().signInWithPassword(email: newEmail, password: password);
      final before = await mailpit.snapshot(oldEmail);
      await auth().updateUser(UserAttributes(email: oldEmail));
      final code = await mailpit.waitForCode(oldEmail, before: before);
      await auth().verifyOTP(
        type: OtpType.emailChange,
        email: oldEmail,
        token: code,
      );
      await auth().signOut();
    });

    await auth().signInWithPassword(email: oldEmail, password: password);
    await openApp(tester);
    await openProfileTab(tester);

    await tapReady(tester, find.text(l10nPt.profileChangeEmail));
    await pumpUntil(tester, find.text(l10nPt.emailNewLabel));

    await tester.enterText(find.byType(TextFormField), newEmail);
    final before = await mailpit.snapshot(newEmail);
    await tapReady(
      tester,
      find.widgetWithText(FilledButton, l10nPt.authSendCode),
    );
    await pumpUntil(tester, find.byType(CodeField));

    final code = await mailpit.waitForCode(newEmail, before: before);
    await tester.enterText(find.byType(CodeField), code);
    await pumpUntil(tester, find.text(l10nPt.emailChanged));

    // Sai e entra com o e-mail novo.
    await signOutFromProfile(tester);
    await fillLogin(tester, newEmail, password);
    await pumpUntil(tester, gamesTab);

    // O antigo não entra mais.
    await signOutFromProfile(tester);
    await fillLogin(tester, oldEmail, password);
    await pumpUntil(tester, find.text(l10nPt.errorAuthInvalidCredentials));
    expect(loginScreen, findsOneWidget);
  });
}
