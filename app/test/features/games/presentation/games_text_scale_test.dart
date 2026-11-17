import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S59 de docs/testes-referencia.md, seção 12.6, com as telas das
/// etapas A e B (na B, o pé de quem está na lista e na espera, e as sheets de
/// saída e de remoção) e da etapa A (Meus jogos, Criar jogo, o detalhe, Editar jogo e os jogos no
/// detalhe do grupo) e a sheet de grupos: fonte do sistema em 150%, num
/// celular pequeno (360 x 640 dp), sem overflow (RNF05).
void main() {
  late TestHarness h;
  const small = Size(360, 640);
  const longPlace = 'Quadra Poliesportiva do Sesc Parnaíba, ao lado da praça';

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    final games = [
      summary(
        locationName: longPlace,
        occupiedSlots: 12,
        status: GameStatus.confirmed,
        myStatus: ParticipantStatus.active,
      ),
      summary(
        id: game2Id,
        groupName: 'Vôlei de Quinta na Areia do Rio Parnaíba',
        locationName: 'Ginásio Verdão',
        myWaitlistPosition: 12,
      ),
    ];
    h.myGames(games);
    h.groupGames(quintaId, games);
    when(() => h.games.fetchMyGroupOptions()).thenAnswer(
      (_) async => [
        quintaOption,
        const GameGroupOption(
          id: areiaId,
          name: 'Vôlei de Quinta na Areia do Rio Parnaíba',
        ),
      ],
    );
    h.game(
      () => game1(
        locationName: longPlace,
        totalCents: 2147483647,
        slotLimit: 30,
        receiverName: 'Ana Souza de Oliveira Albuquerque',
        participants: [
          participant(anaId, 'Ana Souza de Oliveira Albuquerque'),
          participant(
            brunoId,
            'Brunão do vôlei de praia',
            minute: 5,
            status: ParticipantStatus.leftAfterStart,
          ),
        ],
        waitlist: [waiting(carlaId, 'Carlinha das quadras de areia')],
      ),
    );
  });

  Future<void> open(WidgetTester tester, List<String> stack) async {
    await h.pumpApp(tester, textScale: 1.5, size: small, location: stack.first);
    for (final location in stack.skip(1)) {
      await h.push(tester, location);
    }
    expect(h.location, stack.last);
    expect(tester.takeException(), isNull, reason: stack.last);
  }

  testWidgets('S59: Meus jogos, Próximos e Anteriores', (tester) async {
    await open(tester, ['/games']);
    await tester.tap(find.text(l10nPt.gamesFilterPast));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S59: Meus jogos, vazio', (tester) async {
    h.myGames(const []);
    await open(tester, ['/games']);
  });

  testWidgets('S59: Criar jogo, sem chave Pix e com os erros', (tester) async {
    when(() => h.games.hasPixKey()).thenAnswer((_) async => false);
    await open(tester, ['/games', '/games/new']);
    expect(find.text(l10nPt.gamePixNeededBody), findsOneWidget);
    when(() => h.games.hasPixKey()).thenAnswer((_) async => true);
  });

  testWidgets('S59: Criar jogo, com os erros e a sheet de grupos', (
    tester,
  ) async {
    await open(tester, ['/games', '/games/new']);
    final button = buttonWithText<FilledButton>(l10nPt.gamesCreate);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final group = find.byKey(const Key('gameGroupField'));
    await tester.ensureVisible(group);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.gameGroupSheetTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S59: detalhe do jogo, visto pelo admin', (tester) async {
    await open(tester, ['/games', '/games/$game1Id']);
    await tester.tap(find.byTooltip(l10nPt.gameMenuLabel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S59: detalhe do jogo, com o pé da espera', (tester) async {
    h.signedIn(userId: diegoId);
    h.game(
      () => game2(viewerId: diegoId, waitlist: [waiting(brunoId, 'Brunão')]),
    );
    await open(tester, ['/games', '/games/$game2Id']);
    expect(find.text(l10nPt.gameFullHint), findsOneWidget);
  });

  testWidgets('S59: Editar jogo', (tester) async {
    await open(tester, ['/games', '/games/$game1Id', '/games/$game1Id/edit']);
  });

  testWidgets('S59: jogos no detalhe do grupo', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId']);
    await tester.ensureVisible(find.text('Ginásio Verdão'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S59 (etapa B): pé da espera e confirmação de saída', (
    tester,
  ) async {
    h.signedIn(userId: carlaId);
    h.game(
      () => game1(
        viewerId: carlaId,
        locationName: longPlace,
        participants: [participant(anaId, 'Ana Souza de Oliveira Albuquerque')],
        waitlist: [waiting(carlaId, 'Carlinha das quadras de areia')],
      ),
    );
    await open(tester, ['/games', '/games/$game1Id']);
    expect(find.text(l10nPt.gameLeaveWaitlist), findsOneWidget);
    expect(tester.takeException(), isNull);

    h.signedIn(userId: brunoId);
    h.game(
      () => game1(
        viewerId: brunoId,
        locationName: longPlace,
        participants: [
          participant(anaId, 'Ana Souza de Oliveira Albuquerque'),
          participant(brunoId, 'Brunão do vôlei de praia', minute: 5),
        ],
      ),
    );
    await open(tester, ['/games', '/games/$game1Id']);
    final leave = find.text(l10nPt.gameLeave);
    await tester.ensureVisible(leave);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.gameLeaveTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S59 (etapa B): sheet de remoção do admin', (tester) async {
    h.game(
      () => game1(
        locationName: longPlace,
        participants: [
          participant(anaId, 'Ana Souza de Oliveira Albuquerque'),
          participant(brunoId, 'Brunão do vôlei de praia', minute: 5),
        ],
      ),
    );
    await open(tester, ['/games', '/games/$game1Id']);
    final bruno = find.text('Brunão do vôlei de praia');
    await tester.ensureVisible(bruno);
    await tester.pumpAndSettle();
    await tester.tap(bruno);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.gameParticipantRemove));
    await tester.pumpAndSettle();
    expect(
      find.text(l10nPt.gameParticipantRemoveTitle('Brunão do vôlei de praia')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
