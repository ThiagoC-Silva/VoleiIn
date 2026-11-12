import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';

import '../test/helpers/test_app.dart';

/// Cenários L06 e L07 de docs/testes-referencia.md, seção 9.4.
///
/// Roda no emulador, contra o Supabase local com o seed (docs/setup.md, 8):
///
/// ```bash
/// flutter test integration_test --dart-define-from-file=env/local.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  setUp(() async {
    await Supabase.instance.client.auth.signOut();
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('L06: entra com a Ana e continua logado ao reabrir', (
    tester,
  ) async {
    await openApp(tester);

    expect(find.text(l10nPt.authLoginSubtitle), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ana@voleiin.test');
    await tester.enterText(fields.at(1), 'voleiin123');
    await tester.tap(find.widgetWithText(FilledButton, l10nPt.authLoginButton));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10nPt.navGames),
      ),
      findsOneWidget,
    );

    // Fecha e reabre: a sessão continua (RF05).
    await openApp(tester);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10nPt.navGames),
      ),
      findsOneWidget,
    );
    expect(find.text(l10nPt.authLoginSubtitle), findsNothing);
  });

  testWidgets('L07: Sair volta ao login, e o voltar não retorna às abas', (
    tester,
  ) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'ana@voleiin.test',
      password: 'voleiin123',
    );
    await openApp(tester);

    await tester.tap(find.text(l10nPt.navProfile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, l10nPt.authLogout));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(l10nPt.authLoginSubtitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authLoginSubtitle), findsOneWidget);
  });
}
