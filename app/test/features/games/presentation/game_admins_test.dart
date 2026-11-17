import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S48, S49 e S54 de docs/testes-referencia.md, seção 12.6: o menu do
/// admin, o cancelamento e a tela de admins do jogo (docs/ui/telas.md, 7.3 e
/// 7.5; gameAdmins.png, gameAdmins-adicionar.png e game-cancelado.png). Etapa
/// C da fatia 4. A remoção pelo admin (parte do S48) está em
/// game_leave_test.dart, da etapa B.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    when(() => h.games.cancelGame(any())).thenAnswer((_) async {});
    when(
      () => h.games.addGameAdmin(
        gameId: any(named: 'gameId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => h.games.removeGameAdmin(
        gameId: any(named: 'gameId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester, String location) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, location);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10nPt.gameMenuLabel));
    await tester.pumpAndSettle();
  }

  group('S48: menu do admin', () {
    testWidgets('antes do início: Editar, Admins e Cancelar', (tester) async {
      h.game(game1);
      await open(tester, '/games/$game1Id');
      await openMenu(tester);

      expect(find.text(l10nPt.gameEdit), findsOneWidget);
      expect(find.text(l10nPt.gameAdmins), findsOneWidget);
      expect(find.text(l10nPt.gameCancel), findsOneWidget);
    });

    testWidgets('depois do início: sem Editar jogo', (tester) async {
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(game1);
      await open(tester, '/games/$game1Id');
      await openMenu(tester);

      expect(find.text(l10nPt.gameEdit), findsNothing);
      expect(find.text(l10nPt.gameAdmins), findsOneWidget);
      expect(find.text(l10nPt.gameCancel), findsOneWidget);
    });

    testWidgets('jogo cancelado: só Admins do jogo', (tester) async {
      h.game(() => game1(status: GameStatus.cancelled));
      await open(tester, '/games/$game1Id');
      await openMenu(tester);

      expect(find.text(l10nPt.gameAdmins), findsOneWidget);
      expect(find.text(l10nPt.gameCancel), findsNothing);
    });
  });

  testWidgets('S49: Cancelar jogo, confirmar, relê com o topo Cancelado', (
    tester,
  ) async {
    var status = GameStatus.open;
    h.game(() => game1(status: status));
    when(() => h.games.cancelGame(any())).thenAnswer((_) async {
      status = GameStatus.cancelled;
    });
    await open(tester, '/games/$game1Id');
    await openMenu(tester);
    await tester.tap(find.text(l10nPt.gameCancel));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.gameCancelTitle), findsOneWidget);
    expect(find.text(l10nPt.gameCancelBody), findsOneWidget);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.gameCancel));
    await tester.pumpAndSettle();

    verify(() => h.games.cancelGame(game1Id)).called(1);
    expect(find.text(l10nPt.gameCancelled), findsOneWidget);
    expect(find.text(l10nPt.gameStatusCancelled), findsOneWidget);
    expect(find.text(l10nPt.gameReceiverCannotLeave), findsNothing);
  });

  group('S54: admins do jogo', () {
    setUp(() {
      // Ana e Bruno admins; Bruno fora da lista; Carla na lista; Edu na espera.
      h.game(
        () => game1(
          participants: [
            participant(anaId, 'Ana'),
            participant(carlaId, 'Carlinha', minute: 9),
          ],
          waitlist: [waiting(edId, 'Edu')],
          adminIds: const [anaId, brunoId],
        ),
      );
      when(() => h.games.fetchGameAdmins(game1Id)).thenAnswer(
        (_) async => const [
          GameAdmin(userId: brunoId, displayName: 'Brunão'),
          GameAdmin(userId: anaId, displayName: 'Ana'),
        ],
      );
    });

    testWidgets('a tela abre pelo menu, com os subtítulos', (tester) async {
      await open(tester, '/games/$game1Id');
      await openMenu(tester);
      await tester.tap(find.text(l10nPt.gameAdmins));
      await tester.pumpAndSettle();

      expect(h.location, '/games/$game1Id/admins');
      double top(Finder f) => tester.getTopLeft(f).dy;
      final ana = find.text(l10nPt.groupMemberYou('Ana'));
      final bruno = find.text('Brunão');
      expect(top(ana), lessThan(top(bruno)), reason: 'ordem alfabética');
      expect(find.text(l10nPt.gameAdminOnList), findsOneWidget);
      expect(find.text(l10nPt.gameAdminOffList), findsOneWidget);
    });

    testWidgets('Adicionar admin lista só quem está na lista', (tester) async {
      await open(tester, '/games/$game1Id/admins');
      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameAdminAdd));
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.gameAdminAddSheetTitle), findsOneWidget);
      expect(find.text('Carlinha'), findsOneWidget);
      expect(find.text('Edu'), findsNothing);

      await tester.tap(find.text('Carlinha'));
      await tester.pumpAndSettle();
      verify(() => h.games.addGameAdmin(gameId: game1Id, userId: carlaId))
          .called(1);
      expect(find.text(l10nPt.gameAdminAdded('Carlinha')), findsOneWidget);
    });

    testWidgets('remover outro admin, sem confirmação', (tester) async {
      await open(tester, '/games/$game1Id/admins');
      await tester.tap(find.text('Brunão'));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.groupMemberViewProfile), findsOneWidget);
      await tester.tap(find.text(l10nPt.gameAdminRemove));
      await tester.pumpAndSettle();

      verify(() => h.games.removeGameAdmin(gameId: game1Id, userId: brunoId))
          .called(1);
      expect(find.text(l10nPt.gameAdminRemoved('Brunão')), findsOneWidget);
    });

    testWidgets('Ana deixa de ser admin e volta ao detalhe', (tester) async {
      await open(tester, '/games/$game1Id');
      await h.push(tester, '/games/$game1Id/admins');
      await tester.tap(find.text(l10nPt.groupMemberYou('Ana')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.gameAdminStepDown));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.gameAdminStepDownTitle), findsOneWidget);
      await tester.tap(buttonWithText<FilledButton>(l10nPt.gameAdminStepDown));
      await tester.pumpAndSettle();

      verify(() => h.games.removeGameAdmin(gameId: game1Id, userId: anaId))
          .called(1);
      expect(h.location, '/games/$game1Id');
      expect(find.text(l10nPt.gameAdminSteppedDown), findsOneWidget);
    });

    testWidgets('a única admin não toca na própria linha', (tester) async {
      when(() => h.games.fetchGameAdmins(game1Id)).thenAnswer(
        (_) async => const [GameAdmin(userId: anaId, displayName: 'Ana')],
      );
      await open(tester, '/games/$game1Id/admins');
      await tester.tap(find.text(l10nPt.groupMemberYou('Ana')));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.gameAdminStepDown), findsNothing);
    });

    testWidgets('quem não é admin vê "não encontrado"', (tester) async {
      h.signedIn(userId: carlaId);
      h.game(() => game1(viewerId: carlaId));
      await open(tester, '/games/$game1Id/admins');
      expect(find.text(l10nPt.gameAdminAdd), findsNothing);
      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
    });
  });
}
