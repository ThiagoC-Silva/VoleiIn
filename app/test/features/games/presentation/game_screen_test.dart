import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S42 e S50 a S52 de docs/testes-referencia.md, seção 12.6, e as
/// ações da etapa A no detalhe (docs/ui/telas.md, 7.3; game.png,
/// game-admin.png, game-confirmado.png, game-espera.png, game-andamento.png
/// e game-cancelado.png). Sair da lista e da espera são da etapa B (research
/// R12 de specs/003-jogo-etapa-a).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn(userId: brunoId);
    when(() => h.games.joinGame(any())).thenAnswer((_) async {});
    when(() => h.games.joinWaitlist(any())).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester, String gameId) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$gameId');
  }

  Future<void> tapButton<T extends ButtonStyleButton>(
    WidgetTester tester,
    String label,
  ) async {
    final button = buttonWithText<T>(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('S42: Bruno fora da lista', () {
    testWidgets('jogo Aberto: Entrar na lista, sem a chave', (tester) async {
      h.game(
        () => game1(
          viewerId: brunoId,
          participants: [participant(anaId, 'Ana')],
          pixKeyType: null,
          pixKey: null,
        ),
      );
      await open(tester, game1Id);

      expect(buttonWithText<FilledButton>(l10nPt.gameJoin), findsOneWidget);
      expect(find.text(l10nPt.gamePixOnlyParticipants), findsOneWidget);
      expect(find.text(l10nPt.gamePixCopy), findsNothing);
    });

    testWidgets('jogo Confirmado: espera com gameFullHint', (tester) async {
      h.game(
        () => game2(
          viewerId: brunoId,
          waitlist: const [],
        ).copyWith(receiverPixKeyType: null, receiverPixKey: null),
      );
      await open(tester, game2Id);

      expect(find.text(l10nPt.gameFullHint), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.gameJoinWaitlist),
        findsOneWidget,
      );
      expect(find.text(l10nPt.gamePixOnlyParticipants), findsOneWidget);
    });

    testWidgets('avulso de outra pessoa com passagem cancelada', (
      tester,
    ) async {
      h.game(
        () => game1(
          viewerId: brunoId,
          id: standaloneId,
          groupId: null,
          groupName: null,
          locationName: 'Praia do Coqueiro',
          participants: [participant(anaId, 'Ana')],
          isGroupMember: false,
          pixKeyType: null,
          pixKey: null,
        ),
      );
      await open(tester, standaloneId);

      expect(find.text(l10nPt.gameStandalone), findsOneWidget);
      expect(find.text(l10nPt.gameNeedsInvite), findsOneWidget);
      expect(find.text(l10nPt.gameJoin), findsNothing);
      expect(find.text(l10nPt.gameJoinWaitlist), findsNothing);
      expect(find.text(l10nPt.gamePixOnlyParticipants), findsOneWidget);
    });
  });

  group('S50: lista e espera', () {
    testWidgets('numeração, selos e títulos', (tester) async {
      h.signedIn(userId: carlaId);
      h.game(
        () => game1(
          viewerId: carlaId,
          slotLimit: 3,
          status: GameStatus.confirmed,
          participants: [
            // Fora de ordem, como o servidor pode devolver.
            participant(carlaId, 'Carlinha', minute: 9),
            participant(anaId, 'Ana'),
            participant(
              brunoId,
              'Brunão',
              minute: 5,
              status: ParticipantStatus.leftAfterStart,
            ),
          ],
          waitlist: [
            waiting(diegoId, 'Diego', minute: 7),
            waiting(edId, 'Edu', minute: 2),
          ],
        ),
      );
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameListTitle('3', '3')), findsOneWidget);
      expect(find.text('Lista · 3 de 3'), findsOneWidget);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final ana = find.text('Ana').last;
      final bruno = find.text('Brunão');
      final carla = find.text(l10nPt.groupMemberYou('Carlinha'));
      expect(top(ana), lessThan(top(bruno)));
      expect(top(bruno), lessThan(top(carla)));
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);

      expect(find.text(l10nPt.gameReceiver), findsNWidgets(2));
      expect(find.text(l10nPt.gameAdmin), findsOneWidget);
      expect(find.text(l10nPt.gameLeftAfterStartBadge), findsOneWidget);

      await tester.ensureVisible(find.text('Diego'));
      expect(find.text(l10nPt.gameWaitlistTitle('2')), findsOneWidget);
      expect(top(find.text('Edu')), lessThan(top(find.text('Diego'))));
      expect(find.text('1º na espera'), findsOneWidget);
      expect(find.text('2º na espera'), findsOneWidget);
    });

    testWidgets('topo e trio do jogo 1', (tester) async {
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      expect(find.text(quintaName), findsOneWidget);
      expect(find.text('sáb, 21/11'), findsOneWidget);
      expect(find.text('20:00 – 22:00'), findsOneWidget);
      expect(find.text('Quadra do Sesc'), findsOneWidget);
      expect(find.text(l10nPt.gameStatusOpen), findsOneWidget);
      expect(find.text('3/12'), findsNWidgets(2));
      expect(find.text(l10nPt.gameTrioFreeSlots(9)), findsOneWidget);
      expect(find.text('R\$ 10,00'), findsOneWidget);
      expect(find.text(l10nPt.gameTrioEstimate), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('sex, 20/11'), findsOneWidget);
      expect(find.byTooltip(l10nPt.gameOpenMaps), findsOneWidget);
    });

    testWidgets('lista cheia no trio e sem mapa sem link', (tester) async {
      h.game(() => game2(viewerId: brunoId));
      await open(tester, game2Id);

      expect(find.text(l10nPt.gameTrioFull), findsOneWidget);
      expect(find.text(l10nPt.gameStatusConfirmed), findsOneWidget);
      expect(find.byTooltip(l10nPt.gameOpenMaps), findsNothing);
    });

    testWidgets('a espera some depois do início', (tester) async {
      h.now = DateTime.utc(2026, 11, 22, 23, 30);
      h.game(() => game2(viewerId: anaId));
      await open(tester, game2Id);

      expect(find.text(l10nPt.gameWaitlistTitle('1')), findsNothing);
    });
  });

  group('S51 e S52', () {
    testWidgets('S51: evento do Realtime relê, sem SnackBar', (tester) async {
      var participants = game1Participants().take(2).toList();
      h.game(() => game1(viewerId: brunoId, participants: participants));
      await open(tester, game1Id);
      expect(find.text('Carlinha'), findsNothing);
      expect(h.isWatching(game1Id), isTrue);

      participants = game1Participants();
      await h.realtimeEvent(tester, game1Id);

      expect(find.text('Carlinha'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      verify(() => h.games.fetchGame(game1Id)).called(2);
    });

    testWidgets('S51: sair da tela cancela a assinatura', (tester) async {
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);
      await tester.tap(find.byTooltip(l10nPt.commonBack));
      await tester.pumpAndSettle();

      expect(h.isWatching(game1Id), isFalse);
    });

    testWidgets('S52: jogo que o repositório não acha', (tester) async {
      h.gameNotFound(game1Id);
      await open(tester, game1Id);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      expect(find.text(l10nPt.gameJoin), findsNothing);
    });
  });

  group('entrar na lista e na espera', () {
    testWidgets('Entrar na lista chama join_game e relê', (tester) async {
      var joined = false;
      h.game(
        () => game1(
          viewerId: brunoId,
          participants: [
            participant(anaId, 'Ana'),
            if (joined) participant(brunoId, 'Brunão', minute: 5),
          ],
          pixKeyType: joined ? PixKeyType.cpf : null,
          pixKey: joined ? '12345678909' : null,
        ),
      );
      when(() => h.games.joinGame(game1Id)).thenAnswer((_) async {
        joined = true;
      });
      await open(tester, game1Id);
      await tapButton<FilledButton>(tester, l10nPt.gameJoin);

      verify(() => h.games.joinGame(game1Id)).called(1);
      expect(find.text(l10nPt.gameJoined), findsOneWidget);
      expect(find.text(l10nPt.groupMemberYou('Brunão')), findsOneWidget);
      expect(find.text('CPF · 123.456.789-09'), findsOneWidget);
      expect(find.text(l10nPt.gameJoin), findsNothing);
    });

    testWidgets('GAME_FULL: SnackBar, relê e oferece a espera', (tester) async {
      var full = false;
      h.game(
        () => full
            ? game2(viewerId: brunoId, waitlist: const [])
            : game2(
                viewerId: brunoId,
                waitlist: const [],
              ).copyWith(status: GameStatus.open, slotLimit: 3),
      );
      when(() => h.games.joinGame(game2Id)).thenAnswer((_) async {
        full = true;
        throw const AppException(ErrorCode.gameFull);
      });
      await open(tester, game2Id);
      await tapButton<FilledButton>(tester, l10nPt.gameJoin);

      expect(find.text(l10nPt.errorGameFull), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.gameJoinWaitlist),
        findsOneWidget,
      );
    });

    testWidgets('Entrar na lista de espera chama join_waitlist', (
      tester,
    ) async {
      var waitingNow = false;
      h.game(
        () => game2(
          viewerId: brunoId,
          waitlist: [if (waitingNow) waiting(brunoId, 'Brunão')],
        ),
      );
      when(() => h.games.joinWaitlist(game2Id)).thenAnswer((_) async {
        waitingNow = true;
      });
      await open(tester, game2Id);
      await tapButton<FilledButton>(tester, l10nPt.gameJoinWaitlist);

      verify(() => h.games.joinWaitlist(game2Id)).called(1);
      expect(find.text(l10nPt.gameJoinedWaitlist), findsOneWidget);
      expect(find.text(l10nPt.gameWaitlistNotice('1')), findsOneWidget);
      expect(find.text(l10nPt.gameJoinWaitlist), findsNothing);
    });

    testWidgets('GAME_NOT_FULL: SnackBar e o pé passa a Entrar na lista', (
      tester,
    ) async {
      var opened = false;
      h.game(
        () => opened
            ? game2(
                viewerId: brunoId,
                waitlist: const [],
              ).copyWith(status: GameStatus.open, slotLimit: 3)
            : game2(viewerId: brunoId, waitlist: const []),
      );
      when(() => h.games.joinWaitlist(game2Id)).thenAnswer((_) async {
        opened = true;
        throw const AppException(ErrorCode.gameNotFull);
      });
      await open(tester, game2Id);
      await tapButton<FilledButton>(tester, l10nPt.gameJoinWaitlist);

      expect(find.text(l10nPt.errorGameNotFull), findsOneWidget);
      expect(buttonWithText<FilledButton>(l10nPt.gameJoin), findsOneWidget);
    });

    testWidgets('na espera de um jogo Aberto: Entrar na lista', (tester) async {
      h.game(
        () =>
            game2(viewerId: brunoId)
                .copyWith(status: GameStatus.open, slotLimit: 3),
      );
      await open(tester, game2Id);

      expect(buttonWithText<FilledButton>(l10nPt.gameJoin), findsOneWidget);
      expect(find.text(l10nPt.gameWaitlistNotice('1')), findsNothing);
    });
  });

  group('recebedor, admin e tempo', () {
    testWidgets('S44 (chave): o recebedor copia a chave sem formatação', (
      tester,
    ) async {
      h.signedIn();
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      h.game(game1);
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameReceiverCannotLeave), findsOneWidget);
      expect(find.text('CPF · 123.456.789-09'), findsOneWidget);
      await tester.ensureVisible(find.text(l10nPt.gamePixCopy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.gamePixCopy));
      await tester.pumpAndSettle();

      expect(copied, ['12345678909']);
      expect(find.text(l10nPt.gamePixCopied), findsOneWidget);
    });

    testWidgets('admin vê o menu com Editar jogo, que abre a edição', (
      tester,
    ) async {
      h.signedIn();
      h.game(game1);
      await open(tester, game1Id);

      await tester.tap(find.byTooltip(l10nPt.gameMenuLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.gameEdit));
      await tester.pumpAndSettle();

      expect(h.location, '/games/$game1Id/edit');
    });

    testWidgets('quem não é admin não vê o menu', (tester) async {
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      expect(find.byTooltip(l10nPt.gameMenuLabel), findsNothing);
    });

    testWidgets('depois do início, sem Editar jogo nem menu', (tester) async {
      h.signedIn();
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(game1);
      await open(tester, game1Id);

      expect(find.byTooltip(l10nPt.gameMenuLabel), findsNothing);
    });

    testWidgets('em andamento: selo e sem pé para quem está fora', (
      tester,
    ) async {
      h.now = DateTime.utc(2026, 11, 21, 23, 30);
      h.game(
        () =>
            game1(viewerId: brunoId, participants: [participant(anaId, 'Ana')]),
      );
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameInProgress), findsOneWidget);
      expect(find.text(l10nPt.gameJoin), findsNothing);
    });

    testWidgets('depois do fim: aguardando conclusão e lista travada', (
      tester,
    ) async {
      h.now = DateTime.utc(2026, 11, 22, 2);
      h.game(() => game1(viewerId: brunoId));
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameAwaitingCompletion), findsOneWidget);
      expect(find.text(l10nPt.gameListLocked), findsOneWidget);
    });

    testWidgets('cancelado: selo no topo e pé vazio', (tester) async {
      h.game(
        () => game1(
          viewerId: brunoId,
          status: GameStatus.cancelled,
          participants: [participant(anaId, 'Ana')],
          pixKeyType: null,
          pixKey: null,
        ),
      );
      await open(tester, game1Id);

      expect(find.text(l10nPt.gameStatusCancelled), findsOneWidget);
      expect(find.text(l10nPt.gameJoin), findsNothing);
      expect(find.text(l10nPt.gamePixOnlyParticipants), findsOneWidget);
    });
  });

  testWidgets('tocar em outra pessoa abre o perfil na aba Jogos', (
    tester,
  ) async {
    when(() => h.profiles.fetchProfile(any())).thenAnswer(
      (_) async => const Profile(
        id: carlaId,
        name: 'Carla',
        nickname: 'Carlinha',
        displayName: 'Carlinha',
      ),
    );
    h.game(() => game1(viewerId: brunoId));
    await open(tester, game1Id);

    await tester.ensureVisible(find.text('Carlinha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlinha'));
    await tester.pumpAndSettle();
    expect(h.location, '/games/$game1Id/people/$carlaId');

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();
    expect(h.location, '/games/$game1Id');

    // A própria linha não é tocável.
    await tester.ensureVisible(find.text(l10nPt.groupMemberYou('Brunão')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.groupMemberYou('Brunão')));
    await tester.pumpAndSettle();
    expect(h.location, '/games/$game1Id');
  });
}
