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

import '../test/helpers/test_app.dart';

/// Cenário L23 de docs/testes-referencia.md, seção 14
/// (specs/009-pagamentos-etapa-a). Como o L20 a L22, usa o jogo "Quinta
/// aguardando conclusão" do seed (`...0209`, R$ 90,00 e 3 vagas, com Ana,
/// Bruno e Carla; docs/setup.md, seção 8). Antes de abrir o app, a Ana o
/// conclui pela API (se o `pg_cron` ainda não o concluiu): rode logo depois
/// de um `supabase db reset`, sem o L20 a L22 antes.
///
/// ```bash
/// scripts/integration-test.sh integration_test/payments_flow_test.dart
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

  /// O total Recebido do Rateio da recebedora.
  Finder receivedTotal(int cents) => find.descendant(
    of: find.byKey(const Key('splitReceivedTotal')),
    matching: find.text(formatCents(cents)),
  );

  /// O selo da linha do Brunão.
  Finder rowStatus(String label) => find.descendant(
    of: find.ancestor(of: find.text('Brunão'), matching: find.byType(InkWell)),
    matching: find.text(label),
  );

  testWidgets('L23: Ana marca o Brunão como pago e reverte', (tester) async {
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await client.auth.signInWithPassword(
      email: 'ana@voleiin.test',
      password: password,
    );
    // O jogo L23 concluído pelo teste. Se o pg_cron já o concluiu, segue.
    try {
      await client.rpc('complete_game', params: {'p_game_id': awaitingId});
    } on PostgrestException catch (error) {
      if (error.message != 'GAME_NOT_OPEN') rethrow;
    }

    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoleiInApp)),
    );
    container.read(routerProvider).push('/games/$awaitingId/split');
    await pumpUntil(tester, find.text(l10nPt.splitCharges));
    expect(receivedTotal(0), findsOneWidget);

    await tapReady(tester, find.text('Brunão'));
    await tapReady(tester, find.text(l10nPt.markPaidAction));
    await tapReady(tester, button<FilledButton>(l10nPt.markPaidAction).last);
    await pumpUntil(tester, find.text(l10nPt.markedPaid));
    await pumpUntil(tester, receivedTotal(3000));
    await pumpUntil(tester, rowStatus(l10nPt.chargeStatusPaid));

    await tapReady(tester, find.text('Brunão'));
    await tapReady(tester, find.text(l10nPt.revertAction));
    await tapReady(tester, button<FilledButton>(l10nPt.revertAction).last);
    await pumpUntil(tester, find.text(l10nPt.paymentReverted));
    await pumpUntil(tester, receivedTotal(0));
    await pumpUntil(tester, rowStatus(l10nPt.chargeStatusPending));
  });
}
