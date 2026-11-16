import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:voleiin/app.dart';
import 'package:voleiin/core/date_time_picker.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/shared/widgets/list_card.dart';

import '../test/helpers/test_app.dart';

/// Cenário L15 de docs/testes-referencia.md, seção 12.6, sem o cancelamento,
/// que chega na etapa C (specs/003-jogo-etapa-a/tasks.md, T017).
///
/// Roda no emulador, contra o Supabase local com o seed (docs/setup.md, 8),
/// pelos scripts/ (setup.md, 3.1). Sem o cancelamento, o jogo criado fica no
/// banco local até o próximo `supabase db reset`; o nome com a data e a hora
/// o separa dos jogos do seed. Os seletores nativos de data e hora são
/// trocados por respostas fixas: o resto do fluxo, inclusive a criação, passa
/// pelo servidor.
///
/// ```bash
/// scripts/integration-test.sh integration_test/games_flow_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  const quinta = 'Vôlei de Quinta';

  GoTrueClient auth() => Supabase.instance.client.auth;

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  setUp(() async {
    await auth().signOut();
  });

  Future<void> openAs(
    WidgetTester tester,
    String person, {
    required DateTimePicker pickers,
  }) async {
    await auth().signOut();
    await auth().signInWithPassword(
      email: '$person@voleiin.test',
      password: password,
    );
    await tester.pumpWidget(Container());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dateTimePickerProvider.overrideWithValue(pickers)],
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(EditableText),
  );

  /// Se a linha da lista com o nome tem o selo.
  bool rowHas(String name, String badge) => find
      .descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(ListRow)),
        matching: find.text(badge),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('L15: Ana cria um jogo pelo grupo e o vê no grupo e em '
      'Meus jogos', (tester) async {
    final fortaleza = tz.getLocation(fortalezaName);
    final today = tz.TZDateTime.now(fortaleza);
    final day = DateTime(today.year, today.month, today.day + 2);
    final name =
        'L15 ${formatDate(DateTime.now().toUtc())} '
        '${formatTime(DateTime.now().toUtc())}:'
        '${today.second.toString().padLeft(2, '0')}';
    final pickers = _FixedPickers(
      dates: [day, day],
      times: const [
        TimeOfDay(hour: 20, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
      ],
    );

    await openAs(tester, 'ana', pickers: pickers);
    await tapReady(tester, find.text(l10nPt.navGroups).last);
    await tapReady(tester, find.text(quinta));
    await pumpUntil(tester, find.text(l10nPt.groupGamesTitle));
    await tapReady(tester, button<FilledButton>(l10nPt.gamesCreate));
    await pumpUntil(tester, find.text(l10nPt.gameLocationLabel));
    expect(find.text(quinta), findsOneWidget);

    await tester.enterText(field('gameLocationField'), name);
    await tapReady(tester, find.byKey(const Key('gameDateField')));
    await tapReady(tester, find.byKey(const Key('gameStartField')));
    await tapReady(tester, find.byKey(const Key('gameEndField')));
    await tapReady(tester, find.byKey(const Key('gameDeadlineDateField')));
    await tapReady(tester, find.byKey(const Key('gameDeadlineTimeField')));
    await tester.enterText(field('gameTotalField'), '12000');
    await tester.enterText(field('gameSlotLimitField'), '2');
    await tester.pumpAndSettle();
    await tapReady(tester, button<FilledButton>(l10nPt.gamesCreate));

    // O detalhe: Ana na lista, com Recebedor e Admin, e a chave Pix dela.
    await pumpUntil(tester, find.text(l10nPt.gameCreated));
    await pumpUntil(tester, find.text(l10nPt.groupMemberYou('Ana')).last);
    final ana = l10nPt.groupMemberYou('Ana');
    expect(rowHas(ana, l10nPt.gameReceiver), isTrue);
    expect(rowHas(ana, l10nPt.gameAdmin), isTrue);
    expect(find.text('CPF · 529.982.247-25'), findsOneWidget);
    expect(find.text(l10nPt.gameListTitle('1', '2')), findsOneWidget);

    // Em Meus jogos, Próximos.
    await tapReady(tester, find.byTooltip(l10nPt.commonBack));
    await pumpUntil(tester, find.text(l10nPt.gamesFilterUpcoming));
    await pumpUntil(tester, find.text(name));

    // No grupo, em Próximos jogos.
    await tapReady(tester, find.text(l10nPt.navGroups).last);
    await pumpUntil(tester, find.text(l10nPt.groupGamesTitle));
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await pumpUntil(tester, find.text(name));
  });
}

/// Respostas fixas no lugar dos seletores nativos, na ordem dos toques.
class _FixedPickers implements DateTimePicker {
  _FixedPickers({required List<DateTime> dates, required List<TimeOfDay> times})
    : _dates = [...dates],
      _times = [...times];

  final List<DateTime> _dates;
  final List<TimeOfDay> _times;

  @override
  Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) async =>
      _dates.removeAt(0);

  @override
  Future<TimeOfDay?> pickTime(
    BuildContext context, {
    TimeOfDay? initial,
  }) async => _times.removeAt(0);
}
