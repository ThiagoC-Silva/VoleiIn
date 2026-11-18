import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/core/format/money.dart';
import 'package:voleiin/core/router/app_router.dart';
import 'package:voleiin/features/games/presentation/game_badges.dart';

import '../test/helpers/test_app.dart';

/// Cenário L20 de docs/testes-referencia.md, seção 13
/// (specs/006-conclusao-etapa-a). Usa o jogo "Quinta aguardando conclusão"
/// do seed (`...0209`, R$ 90,00 e 3 vagas; docs/setup.md, seção 8) e o deixa
/// Concluído: rode logo depois de um `supabase db reset`, antes que a
/// conclusão automática o feche (uns 50 min depois do reset).
///
/// ```bash
/// scripts/integration-test.sh integration_test/completion_flow_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  const awaitingId = '00000000-0000-0000-0000-000000000209';

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

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
    throw TestFailure('Não apareceu em ${timeout.inSeconds} s: $finder');
  }

  Future<void> tapReady(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpUntil(tester, finder);
    await tester.ensureVisible(finder);
    await pumpUntil(tester, finder.hitTestable());
    await tester.tap(finder);
  }

  Finder button<T extends Widget>(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(T));

  testWidgets('L20: Ana conclui o jogo e vê o Rateio', (tester) async {
    final auth = Supabase.instance.client.auth;
    await auth.signOut();
    await auth.signInWithPassword(
      email: 'ana@voleiin.test',
      password: password,
    );
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();

    // O detalhe pelo roteador, como no L16: os cards repetem o local.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoleiInApp)),
    );
    container.read(routerProvider).push('/games/$awaitingId');
    await tester.pumpAndSettle();

    await tapReady(tester, button<FilledButton>(l10nPt.gameComplete));
    await pumpUntil(tester, find.text(l10nPt.completeSummaryTitle));
    await pumpUntil(tester, find.text(formatCents(3000)));
    await pumpUntil(tester, find.text(formatCents(6000)));

    await tapReady(tester, button<FilledButton>(l10nPt.gameComplete));
    await tapReady(
      tester,
      button<FilledButton>(l10nPt.completeConfirmAction).last,
    );
    await pumpUntil(tester, find.text(l10nPt.gameCompleted));

    // O Rateio: Brunão e Carlinha com R$ 30,00 e Pendente.
    await pumpUntil(tester, find.text(l10nPt.splitCharges));
    for (final name in ['Brunão', 'Carlinha']) {
      await pumpUntil(tester, find.text(name));
    }
    final badges = tester.widgetList<ChargeStatusBadge>(
      find.byType(ChargeStatusBadge),
    );
    expect(badges.map((b) => b.status.value), ['pending', 'pending']);
    expect(find.text(formatCents(3000)), findsWidgets);

    // Meus jogos, em Anteriores, com Concluído.
    container.read(routerProvider).go('/games');
    await tester.pumpAndSettle();
    await tapReady(tester, find.text(l10nPt.gamesFilterPast));
    await pumpUntil(tester, find.text(l10nPt.gameStatusCompleted));
  });
}
