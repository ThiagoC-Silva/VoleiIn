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

/// Cenário L21 de docs/testes-referencia.md, seção 13
/// (specs/007-conclusao-etapa-b). Como o L20, usa o jogo "Quinta aguardando
/// conclusão" do seed (`...0209`, R$ 90,00 e 3 vagas, com Ana, Bruno e Carla;
/// docs/setup.md, seção 8) e o deixa Concluído: rode logo depois de um
/// `supabase db reset`, sem o L20 antes.
///
/// ```bash
/// scripts/integration-test.sh integration_test/penalties_flow_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  const awaitingId = '00000000-0000-0000-0000-000000000209';
  const carlaId = '00000000-0000-0000-0000-00000000000c';

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

  /// O total Pendente do Rateio da recebedora.
  Finder pendingTotal(int cents) => find.descendant(
    of: find.byKey(const Key('splitPendingTotal')),
    matching: find.text(formatCents(cents)),
  );

  testWidgets('L21: Ana marca a falta da Carla, conclui e isenta a multa', (
    tester,
  ) async {
    final auth = Supabase.instance.client.auth;
    await auth.signOut();
    await auth.signInWithPassword(
      email: 'ana@voleiin.test',
      password: password,
    );
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VoleiInApp)),
    );
    container.read(routerProvider).push('/games/$awaitingId');
    await tester.pumpAndSettle();

    await tapReady(tester, button<FilledButton>(l10nPt.gameComplete));
    await pumpUntil(tester, find.text(l10nPt.completeAbsentTitle));
    await tapReady(
      tester,
      find.descendant(
        of: find.byKey(const Key('absent-$carlaId')),
        matching: find.byType(Checkbox),
      ),
    );
    // O resumo volta com a falta: o botão só habilita com ele carregado.
    await pumpUntil(tester, find.text(formatCents(6000)));
    final complete = button<FilledButton>(l10nPt.gameComplete);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (tester.widget<FilledButton>(complete).onPressed == null &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tapReady(tester, complete);
    await tapReady(
      tester,
      button<FilledButton>(l10nPt.completeConfirmAction).last,
    );
    await pumpUntil(tester, find.text(l10nPt.gameCompleted));

    // O Rateio: a Carlinha com Multa por falta, Pendente de R$ 60,00.
    await pumpUntil(tester, find.text(l10nPt.splitCharges));
    await pumpUntil(tester, find.text(l10nPt.chargeKindAbsence));
    expect(pendingTotal(6000), findsOneWidget);

    await tapReady(tester, find.text('Carlinha'));
    await tapReady(tester, find.text(l10nPt.waiveAction));
    await tapReady(tester, button<FilledButton>(l10nPt.waiveAction).last);
    await pumpUntil(tester, find.text(l10nPt.penaltyWaived));

    await pumpUntil(tester, find.text(l10nPt.splitWaived));
    await pumpUntil(tester, find.text(l10nPt.chargeWaivedManual));
    await pumpUntil(tester, pendingTotal(3000));
  });
}
