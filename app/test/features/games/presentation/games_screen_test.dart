import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S36 e S37 de docs/testes-referencia.md, seção 12.6
/// (docs/ui/telas.md, 7.1; games.png, games-anteriores.png e
/// games-vazio.png).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.game(game1);
  });

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group('S36: Próximos e Anteriores', () {
    setUp(() {
      h.myGames([
        // Fora de ordem, como o servidor pode devolver.
        summary(
          id: game2Id,
          locationName: 'Ginásio Verdão',
          startsAt: DateTime.utc(2026, 11, 22, 23),
          status: GameStatus.confirmed,
          slotLimit: 2,
          occupiedSlots: 2,
          myWaitlistPosition: 2,
        ),
        summary(occupiedSlots: 2, myStatus: ParticipantStatus.active),
        summary(
          id: standaloneId,
          groupName: null,
          locationName: 'Praia do Coqueiro',
          startsAt: DateTime.utc(2026, 11, 20, 21),
          slotLimit: 4,
          occupiedSlots: 1,
        ),
        summary(
          id: cancelledId,
          locationName: 'Arena Delta',
          startsAt: DateTime.utc(2026, 11, 19, 23),
          status: GameStatus.cancelled,
          occupiedSlots: 2,
        ),
      ]);
    });

    testWidgets('ordem pelo início, com os selos da pessoa', (tester) async {
      await h.pumpApp(tester, location: '/games');

      expect(find.text(l10nPt.gamesFilterUpcoming), findsOneWidget);
      expect(find.text(l10nPt.gamesFilterPast), findsOneWidget);

      // Avulso (20/11), Quadra do Sesc (21/11), Ginásio Verdão (22/11).
      expect(
        top(tester, 'Praia do Coqueiro'),
        lessThan(top(tester, 'Quadra do Sesc')),
      );
      expect(find.text(l10nPt.gameStandalone), findsOneWidget);
      expect(find.text('2/12'), findsOneWidget);
      expect(find.text(l10nPt.gameOnList), findsOneWidget);

      // A lista é montada sob demanda: rola até o terceiro card.
      await tester.scrollUntilVisible(find.text('Ginásio Verdão'), 200);
      expect(
        top(tester, 'Quadra do Sesc'),
        lessThan(top(tester, 'Ginásio Verdão')),
      );
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text(l10nPt.gameWaitlistPosition('2')), findsOneWidget);
      expect(find.text('2º na espera'), findsOneWidget);
      expect(find.text(l10nPt.gameStatusConfirmed), findsOneWidget);
      expect(find.text('Vôlei de Quinta'), findsWidgets);

      // O cancelado só aparece em Anteriores.
      expect(find.text('Arena Delta'), findsNothing);
      expect(find.text(l10nPt.gameStatusCancelled), findsNothing);
    });

    testWidgets('o cancelado aparece no chip Anteriores', (tester) async {
      await h.pumpApp(tester, location: '/games');
      await tester.tap(find.text(l10nPt.gamesFilterPast));
      await tester.pumpAndSettle();

      expect(find.text('Arena Delta'), findsOneWidget);
      expect(find.text(l10nPt.gameStatusCancelled), findsOneWidget);
      expect(find.text('Quadra do Sesc'), findsNothing);
      expect(find.text('Praia do Coqueiro'), findsNothing);
    });

    testWidgets('anteriores do mais recente para o mais antigo', (
      tester,
    ) async {
      h.myGames([
        summary(
          id: cancelledId,
          locationName: 'Arena Delta',
          startsAt: DateTime.utc(2026, 11, 7, 23),
          status: GameStatus.completed,
        ),
        summary(
          locationName: 'Quadra do Sesc',
          startsAt: DateTime.utc(2026, 11, 14, 23),
          status: GameStatus.cancelled,
        ),
      ]);
      await h.pumpApp(tester, location: '/games');
      await tester.tap(find.text(l10nPt.gamesFilterPast));
      await tester.pumpAndSettle();

      expect(
        top(tester, 'Quadra do Sesc'),
        lessThan(top(tester, 'Arena Delta')),
      );
      expect(find.text(l10nPt.gameStatusCompleted), findsOneWidget);
    });

    testWidgets('tocar no card abre o detalhe na aba Jogos', (tester) async {
      await h.pumpApp(tester, location: '/games');
      await tester.tap(find.text('Quadra do Sesc'));
      await tester.pumpAndSettle();

      expect(h.location, '/games/$game1Id');
    });
  });

  group('S37: sem jogos', () {
    testWidgets('estado vazio e o botão Criar jogo', (tester) async {
      await h.pumpApp(tester, location: '/games');

      expect(find.text(l10nPt.gamesEmptyUpcomingTitle), findsOneWidget);
      expect(find.text(l10nPt.gamesEmptyUpcomingBody), findsOneWidget);
      expect(buttonWithText<FilledButton>(l10nPt.gamesCreate), findsOneWidget);
    });

    testWidgets('Anteriores vazio', (tester) async {
      await h.pumpApp(tester, location: '/games');
      await tester.tap(find.text(l10nPt.gamesFilterPast));
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.gamesEmptyPastTitle), findsOneWidget);
      expect(find.text(l10nPt.gamesEmptyPastBody), findsOneWidget);
    });

    testWidgets('Criar jogo abre a criação sem grupo', (tester) async {
      await h.pumpApp(tester, location: '/games');
      await tester.tap(buttonWithText<FilledButton>(l10nPt.gamesCreate));
      await tester.pumpAndSettle();

      expect(h.location, '/games/new');
    });
  });

  testWidgets('sem conexão, com Tentar de novo', (tester) async {
    when(
      () => h.games.fetchMyGames(),
    ).thenAnswer((_) async => throw const AppException(ErrorCode.noConnection));
    await h.pumpApp(tester, location: '/games');

    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);
    h.myGames([summary()]);
    await tester.tap(find.text(l10nPt.commonTryAgain));
    await tester.pumpAndSettle();
    expect(find.text('Quadra do Sesc'), findsOneWidget);
  });
}
