import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S55 de docs/testes-referencia.md, seção 12.6: os jogos no detalhe
/// do grupo (docs/ui/telas.md, 7.6; group-jogos.png). A seção entra na etapa
/// A (research R13 de specs/003-jogo-etapa-a); a saída do grupo com jogos é
/// da etapa C.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    h.game(game1);
    when(() => h.games.fetchMyGroupOptions())
        .thenAnswer((_) async => [quintaOption, areiaOption]);
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
  }

  testWidgets('S55: Próximos jogos com os cards, na ordem do início', (
    tester,
  ) async {
    // O servidor só devolve os Abertos e Confirmados do grupo.
    h.groupGames(quintaId, [
      summary(
        id: game2Id,
        locationName: 'Ginásio Verdão',
        startsAt: DateTime.utc(2026, 11, 22, 23),
        status: GameStatus.confirmed,
        slotLimit: 2,
        occupiedSlots: 2,
      ),
      summary(),
    ]);
    await open(tester);

    await tester.ensureVisible(find.text('Ginásio Verdão'));
    expect(find.text(l10nPt.groupGamesTitle), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Quadra do Sesc')).dy,
      lessThan(tester.getTopLeft(find.text('Ginásio Verdão')).dy),
    );
    verify(() => h.games.fetchGroupGames(quintaId)).called(1);
  });

  testWidgets('S55: Criar jogo abre a criação com o grupo', (tester) async {
    await open(tester);
    final create = buttonWithText<FilledButton>(l10nPt.gamesCreate);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(h.router.state.uri.toString(), '/games/new?groupId=$quintaId');
    expect(find.text(quintaName), findsOneWidget);
  });

  testWidgets('S55: grupo sem jogos', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text(l10nPt.groupGamesEmpty));

    expect(find.text(l10nPt.groupGamesTitle), findsOneWidget);
    expect(find.text(l10nPt.groupGamesEmpty), findsOneWidget);
  });

  testWidgets('tocar no card abre o detalhe do jogo na aba Jogos', (
    tester,
  ) async {
    h.groupGames(quintaId, [summary()]);
    await open(tester);
    await tester.ensureVisible(find.text('Quadra do Sesc'));
    await tester.tap(find.text('Quadra do Sesc'));
    await tester.pumpAndSettle();

    expect(h.location, '/games/$game1Id');
  });

  testWidgets('puxar para baixo relê o grupo e os jogos', (tester) async {
    await open(tester);
    await tester.fling(find.text(quintaName).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(() => h.games.fetchGroupGames(quintaId)).called(2);
  });
}
