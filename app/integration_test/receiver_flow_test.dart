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
import 'package:voleiin/shared/widgets/bottom_nav.dart';

import '../test/helpers/test_app.dart';

/// Cenário L22 de docs/testes-referencia.md, seção 13
/// (specs/008-conclusao-etapa-c). Como o L20 e o L21, usa o jogo "Quinta
/// aguardando conclusão" do seed (`...0209`, R$ 90,00 e 3 vagas, com Ana,
/// Bruno e Carla; docs/setup.md, seção 8). Antes de abrir o app, a Ana o
/// conclui pela API (se o `pg_cron` ainda não o concluiu): rode logo depois
/// de um `supabase db reset`, sem o L20 e o L21 antes.
///
/// ```bash
/// scripts/integration-test.sh integration_test/receiver_flow_test.dart
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

  testWidgets('L22: Ana troca o recebedor para o Bruno e abre Cobranças', (
    tester,
  ) async {
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await client.auth.signInWithPassword(
      email: 'ana@voleiin.test',
      password: password,
    );
    // O jogo L22 concluído pelo teste. Se o pg_cron já o concluiu, segue.
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
    container.read(routerProvider).push('/games/$awaitingId');
    await tester.pumpAndSettle();

    await tapReady(tester, find.byTooltip(l10nPt.gameMenuLabel));
    await tapReady(tester, find.text(l10nPt.gameChangeReceiver).last);
    await pumpUntil(tester, find.text(l10nPt.receiverChangeAfterBody));
    await tapReady(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Brunão'),
      ),
    );
    await tapReady(
      tester,
      button<FilledButton>(l10nPt.receiverChangeConfirmAction).last,
    );
    await pumpUntil(tester, find.text(l10nPt.receiverChanged('Brunão')));

    // O detalhe mostra o Brunão como recebedor.
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(const Key('receiverCard')),
        matching: find.text('Brunão'),
      ),
    );

    // Cobranças: a linha do L22 em A pagar, para o Brunão, R$ 30,00.
    await tapReady(
      tester,
      find.descendant(
        of: find.byType(VoleiBottomNav),
        matching: find.text(l10nPt.navCharges),
      ),
    );
    await pumpUntil(tester, find.text(l10nPt.splitOwedTo('Brunão')));
    expect(
      find.descendant(
        of: find.byKey(const Key('toPay-$awaitingId')),
        matching: find.text(formatCents(3000)),
      ),
      findsOneWidget,
    );
  });
}
