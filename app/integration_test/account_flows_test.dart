import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';

import '../test/helpers/test_app.dart';

/// Fluxos L08 a L11 de docs/testes-referencia.md, seção 10.4.
///
/// Rodam no emulador (API 29 e 36), contra o Supabase local com o seed. O código
/// chega pelo Mailpit, lido pela API dele em `http://10.0.2.2:54324`. Cada fluxo
/// deixa o seed como encontrou, para rodar de novo sem `supabase db reset`:
///
/// ```bash
/// flutter test integration_test -d emulator-5554 --dart-define-from-file=env/local.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const mailpit = 'http://10.0.2.2:54324';
  const seedPassword = 'voleiin123';

  SupabaseClient db() => Supabase.instance.client;

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  setUp(() async => db().auth.signOut());

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  Finder appBarTitle(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// Código de 6 dígitos do e-mail mais recente para [address], pelo assunto
  /// (docs/copy.md, 6.9). Espera até 20 s o e-mail chegar.
  Future<String> codeFor(String address, {DateTime? after}) async {
    final since =
        after ?? DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    for (var attempt = 0; attempt < 20; attempt++) {
      final response = await http.get(
        Uri.parse(
          '$mailpit/api/v1/search?query=${Uri.encodeQueryComponent('to:"$address"')}&limit=5',
        ),
      );
      final messages = (jsonDecode(response.body)['messages'] as List)
          .cast<Map<String, dynamic>>()
          .where((m) => DateTime.parse(m['Created'] as String).isAfter(since));
      for (final message in messages) {
        final match = RegExp(r'\b(\d{6})\b')
            .firstMatch(message['Subject'] as String);
        if (match != null) return match.group(1)!;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('No code e-mail for $address in Mailpit');
  }

  Future<void> login(WidgetTester tester, String email, String password) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tap(
      tester,
      find.widgetWithText(FilledButton, l10nPt.authLoginButton),
    );
  }

  testWidgets('L08: cria a conta, confirma pelo código e aceita os termos', (
    tester,
  ) async {
    final email =
        'carla.l08.${DateTime.now().millisecondsSinceEpoch}@voleiin.test';
    final started = DateTime.now().toUtc();
    await openApp(tester);

    await tap(
      tester,
      find.widgetWithText(TextButton, l10nPt.authCreateAccount),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Carla Souza');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'senhaDaCarla8');
    await tap(
      tester,
      find.widgetWithText(FilledButton, l10nPt.authCreateAccountButton),
    );

    expect(
      find.text(l10nPt.authCodeSent(email), findRichText: true),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      await codeFor(email, after: started),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(l10nPt.termsSubtitleFirst), findsOneWidget);
    await tap(tester, find.byType(Checkbox));
    await tap(
      tester,
      find.widgetWithText(FilledButton, l10nPt.termsAcceptButton),
    );

    expect(appBarTitle(l10nPt.navGames), findsOneWidget);
    await tap(tester, find.text(l10nPt.navProfile).last);
    expect(find.text('Carla Souza'), findsOneWidget);
  });

  testWidgets('L09: Bruno recupera a senha pelo código e entra com a nova', (
    tester,
  ) async {
    const email = 'bruno@voleiin.test';
    const newPassword = 'novaSenhaDoBruno9';
    final started = DateTime.now().toUtc();
    try {
      await openApp(tester);
      await tap(
        tester,
        find.widgetWithText(TextButton, l10nPt.authForgotPassword),
      );
      await tester.enterText(find.byType(TextFormField), email);
      await tap(tester, find.widgetWithText(FilledButton, l10nPt.authSendCode));

      await tester.enterText(
        find.byType(TextField).first,
        await codeFor(email, after: started),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, newPassword);
      await tap(
        tester,
        find.widgetWithText(FilledButton, l10nPt.authSaveNewPassword),
      );
      expect(appBarTitle(l10nPt.navGames), findsOneWidget);

      await db().auth.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await login(tester, email, newPassword);
      expect(appBarTitle(l10nPt.navGames), findsOneWidget);

      // A senha antiga não entra mais.
      await db().auth.signOut();
      await expectLater(
        db().auth.signInWithPassword(email: email, password: seedPassword),
        throwsA(isA<AuthException>()),
      );
    } finally {
      // Devolve a senha do seed.
      await db().auth.signInWithPassword(email: email, password: newPassword);
      await db().auth.updateUser(UserAttributes(password: seedPassword));
      await db().auth.signOut();
    }
  });

  testWidgets(
    'L10: Ana muda o apelido e o telefone, e o app mostra ao reabrir',
    (tester) async {
      final ana = (await db().auth.signInWithPassword(
        email: 'ana@voleiin.test',
        password: seedPassword,
      )).user!;
      final original = await db()
          .from('profile_private')
          .select('phone, phone_visible')
          .eq('user_id', ana.id)
          .single();
      try {
        await openApp(tester);
        await tap(tester, find.text(l10nPt.navProfile).last);
        await tap(tester, find.text(l10nPt.profileEdit));

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(1), 'Aninha');
        await tester.enterText(fields.at(2), '86988881111');
        await tap(tester, find.widgetWithText(FilledButton, l10nPt.commonSave));

        // Fecha e reabre o app.
        await openApp(tester);
        await tap(tester, find.text(l10nPt.navProfile).last);
        expect(find.text('Aninha'), findsOneWidget);
        await tap(tester, find.text(l10nPt.profileEdit));
        expect(find.text('(86) 98888-1111'), findsOneWidget);
      } finally {
        await db().from('profiles').update({'nickname': null}).eq('id', ana.id);
        await db()
            .from('profile_private')
            .update(original)
            .eq('user_id', ana.id);
        await db().auth.signOut();
      }
    },
  );

  testWidgets('L11: Diego troca o e-mail pelo código e entra com o novo', (
    tester,
  ) async {
    const oldEmail = 'diego@voleiin.test';
    final newEmail =
        'diego.l11.${DateTime.now().millisecondsSinceEpoch}@voleiin.test';
    var changed = false;
    try {
      await db().auth.signInWithPassword(
        email: oldEmail,
        password: seedPassword,
      );
      await openApp(tester);
      await tap(tester, find.text(l10nPt.navProfile).last);
      await tap(tester, find.text(l10nPt.profileChangeEmail));

      final started = DateTime.now().toUtc();
      await tester.enterText(find.byType(TextFormField), newEmail);
      await tap(tester, find.widgetWithText(FilledButton, l10nPt.authSendCode));
      await tester.enterText(
        find.byType(TextField),
        await codeFor(newEmail, after: started),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
      changed = true;
      expect(find.text(newEmail), findsOneWidget);

      await db().auth.signOut();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await login(tester, newEmail, seedPassword);
      expect(appBarTitle(l10nPt.navGames), findsOneWidget);

      // O e-mail antigo não entra mais.
      await db().auth.signOut();
      await expectLater(
        db().auth.signInWithPassword(email: oldEmail, password: seedPassword),
        throwsA(isA<AuthException>()),
      );
    } finally {
      if (changed) {
        // Devolve o e-mail do seed, pelo mesmo fluxo de código.
        await db().auth.signInWithPassword(
          email: newEmail,
          password: seedPassword,
        );
        final started = DateTime.now().toUtc();
        await db().auth.updateUser(UserAttributes(email: oldEmail));
        await db().auth.verifyOTP(
          type: OtpType.emailChange,
          email: oldEmail,
          token: await codeFor(oldEmail, after: started),
        );
      }
      await db().auth.signOut();
    }
  });
}
