import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S60 de docs/testes-referencia.md, seção 12.6, e a lista de
/// acessibilidade de docs/ui/design-system.md, seção 8 (RNF05), nas telas das
/// etapas A a C: área de toque de 48 x 48 dp, rótulo para o TalkBack em todo alvo
/// de toque e contraste de 4,5:1 no texto. A fonte em 150% é o S59
/// (games_text_scale_test.dart).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    h.myGames([
      summary(myStatus: ParticipantStatus.active),
      summary(
        id: game2Id,
        locationName: 'Ginásio Verdão',
        startsAt: DateTime.utc(2026, 11, 22, 23),
        status: GameStatus.confirmed,
        slotLimit: 2,
        occupiedSlots: 2,
        myWaitlistPosition: 1,
      ),
    ]);
    h.groupGames(quintaId, [summary()]);
    when(() => h.games.fetchMyGroupOptions())
        .thenAnswer((_) async => [quintaOption, areiaOption]);
    h.game(game1);
  });

  Future<void> open(WidgetTester tester, List<String> stack) async {
    await h.pumpApp(tester, location: stack.first);
    for (final location in stack.skip(1)) {
      await h.push(tester, location);
    }
    expect(h.location, stack.last);
  }

  Future<void> meetsChecklist(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('S60: o card de Meus jogos tem o gameCardLabel', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, ['/games']);

    expect(
      find.bySemanticsLabel(
        l10nPt.gameCardLabel(
          quintaName,
          'sáb, 21/11',
          '20:00',
          'Quadra do Sesc',
          l10nPt.gameStatusOpen,
        ),
      ),
      findsOneWidget,
    );
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('Meus jogos, Anteriores vazio', (tester) async {
    await open(tester, ['/games']);
    await tester.tap(find.text(l10nPt.gamesFilterPast));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
  });

  testWidgets('S60: Criar jogo, com os botões do contador', (tester) async {
    await open(tester, ['/games', '/games/new']);
    expect(find.byTooltip(l10nPt.gameSlotLimitDecrease), findsOneWidget);
    expect(find.byTooltip(l10nPt.gameSlotLimitIncrease), findsOneWidget);
    for (final label in [
      l10nPt.gameSlotLimitDecrease,
      l10nPt.gameSlotLimitIncrease,
    ]) {
      final size = tester.getSize(find.byTooltip(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    await meetsChecklist(tester);
  });

  testWidgets('Criar jogo, sem chave Pix', (tester) async {
    when(() => h.games.hasPixKey()).thenAnswer((_) async => false);
    await open(tester, ['/games', '/games/new']);
    await meetsChecklist(tester);
  });

  testWidgets('S60: detalhe, com o menu e o mapa rotulados', (tester) async {
    await open(tester, ['/games', '/games/$game1Id']);
    for (final label in [l10nPt.gameMenuLabel, l10nPt.gameOpenMaps]) {
      final size = tester.getSize(find.byTooltip(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
    await meetsChecklist(tester);
  });

  testWidgets('detalhe Confirmado, visto de fora', (tester) async {
    h.signedIn(userId: diegoId);
    h.game(() => game2(viewerId: diegoId));
    await open(tester, ['/games', '/games/$game2Id']);
    await meetsChecklist(tester);
  });

  testWidgets('detalhe cancelado', (tester) async {
    h.game(() => game1(status: GameStatus.cancelled));
    await open(tester, ['/games', '/games/$game1Id']);
    await meetsChecklist(tester);
  });

  testWidgets('Editar jogo', (tester) async {
    await open(tester, ['/games', '/games/$game1Id', '/games/$game1Id/edit']);
    await meetsChecklist(tester);
  });

  testWidgets('detalhe do grupo com os jogos', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId']);
    await meetsChecklist(tester);
  });

  testWidgets('S60 (etapa B): pé de quem está na lista e na espera', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    h.signedIn(userId: brunoId);
    h.game(() => game1(viewerId: brunoId));
    await open(tester, ['/games', '/games/$game1Id']);
    await meetsChecklist(tester);

    h.game(() => game2(viewerId: brunoId));
    await open(tester, ['/games', '/games/$game2Id']);
    await meetsChecklist(tester);
    semantics.dispose();
  });

  testWidgets('S60 (etapa C): admins do jogo', (tester) async {
    final semantics = tester.ensureSemantics();
    when(() => h.games.fetchGameAdmins(game1Id)).thenAnswer(
      (_) async => const [GameAdmin(userId: anaId, displayName: 'Ana')],
    );
    await open(tester, ['/games', '/games/$game1Id', '/games/$game1Id/admins']);
    await meetsChecklist(tester);
    semantics.dispose();
  });
}
