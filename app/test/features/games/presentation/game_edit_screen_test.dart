import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S53 de docs/testes-referencia.md, seção 12.6, e os estados de
/// Editar jogo (docs/ui/telas.md, 7.4; gameEdit.png).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    // 3 ocupadas e limite 4.
    h.game(() => game1(slotLimit: 4));
    when(
      () => h.games.setSlotLimit(
        gameId: any(named: 'gameId'),
        slotLimit: any(named: 'slotLimit'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => h.games.updateGame(
        gameId: any(named: 'gameId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async {});
  });

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(EditableText),
  );

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$game1Id');
    await h.push(tester, '/games/$game1Id/edit');
  }

  Future<void> save(WidgetTester tester) async {
    final button = buttonWithText<FilledButton>(l10nPt.commonSave);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> decrease(WidgetTester tester) async {
    final button = find.byTooltip(l10nPt.gameSlotLimitDecrease);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  void verifyNoSave() {
    verifyNever(
      () => h.games.setSlotLimit(
        gameId: any(named: 'gameId'),
        slotLimit: any(named: 'slotLimit'),
      ),
    );
    verifyNever(
      () => h.games.updateGame(
        gameId: any(named: 'gameId'),
        input: any(named: 'input'),
      ),
    );
  }

  testWidgets('os campos vêm preenchidos, com o grupo só como texto', (
    tester,
  ) async {
    await open(tester);

    expect(find.text(l10nPt.gameEdit), findsOneWidget);
    expect(find.text(quintaName), findsOneWidget);
    expect(find.byKey(const Key('gameGroupField')), findsNothing);
    expect(find.text('Quadra do Sesc'), findsOneWidget);
    expect(find.text('https://maps.app.goo.gl/Sesc21'), findsOneWidget);
    expect(find.text('21/11/2026'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text('20/11/2026'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('120,00'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  group('S53', () {
    testWidgets('− desabilitado no número de ocupadas, com a dica', (
      tester,
    ) async {
      await open(tester);
      expect(find.text(l10nPt.gameSlotsOccupiedHint(3)), findsOneWidget);
      expect(find.text('3 pessoas na lista'), findsOneWidget);

      await decrease(tester);
      expect(find.text('3'), findsOneWidget);
      final minus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(l10nPt.gameSlotLimitDecrease),
          matching: find.byType(IconButton),
        ),
      );
      expect(minus.onPressed, isNull);
    });

    testWidgets('mudar o limite e o local: set_slot_limit antes', (
      tester,
    ) async {
      final calls = <String>[];
      when(
        () => h.games.setSlotLimit(
          gameId: any(named: 'gameId'),
          slotLimit: any(named: 'slotLimit'),
        ),
      ).thenAnswer((_) async => calls.add('set_slot_limit'));
      when(
        () => h.games.updateGame(
          gameId: any(named: 'gameId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer((_) async => calls.add('update_game'));
      await open(tester);

      await decrease(tester);
      await tester.enterText(field('gameLocationField'), 'Ginásio Verdão');
      await save(tester);

      expect(calls, ['set_slot_limit', 'update_game']);
      verify(() => h.games.setSlotLimit(gameId: game1Id, slotLimit: 3))
          .called(1);
      final input =
          verify(
                () => h.games.updateGame(
                  gameId: game1Id,
                  input: captureAny(named: 'input'),
                ),
              ).captured.single
              as GameInput;
      expect(input.locationName, 'Ginásio Verdão');
      expect(input.startsAt, game1Start);
      expect(input.endsAt, game1End);
      expect(input.cancellationDeadline, game1Deadline);
      expect(input.totalCents, 12000);
      expect(find.text(l10nPt.gameSaved), findsOneWidget);
      expect(h.location, '/games/$game1Id');
    });

    testWidgets('mudar só o local: só update_game', (tester) async {
      await open(tester);
      await tester.enterText(field('gameLocationField'), 'Ginásio Verdão');
      await save(tester);

      verifyNever(
        () => h.games.setSlotLimit(
          gameId: any(named: 'gameId'),
          slotLimit: any(named: 'slotLimit'),
        ),
      );
      verify(
        () => h.games.updateGame(
          gameId: game1Id,
          input: any(named: 'input'),
        ),
      ).called(1);
    });

    testWidgets('mudar só o limite: só set_slot_limit', (tester) async {
      await open(tester);
      await decrease(tester);
      await save(tester);

      verify(() => h.games.setSlotLimit(gameId: game1Id, slotLimit: 3))
          .called(1);
      verifyNever(
        () => h.games.updateGame(
          gameId: any(named: 'gameId'),
          input: any(named: 'input'),
        ),
      );
    });

    testWidgets('sem mudança, só volta', (tester) async {
      await open(tester);
      await save(tester);

      verifyNoSave();
      expect(h.location, '/games/$game1Id');
      expect(find.text(l10nPt.gameSaved), findsNothing);
    });

    testWidgets('limite aceito e update_game com erro: a tela continua', (
      tester,
    ) async {
      when(
        () => h.games.updateGame(
          gameId: any(named: 'gameId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer(
        (_) async => throw const AppException(ErrorCode.invalidGameDates),
      );
      await open(tester);
      await decrease(tester);
      await tester.enterText(field('gameLocationField'), 'Ginásio Verdão');
      await save(tester);

      expect(find.text(l10nPt.errorInvalidGameDates), findsOneWidget);
      expect(h.location, '/games/$game1Id/edit');
      expect(find.text('Ginásio Verdão'), findsOneWidget);
    });

    testWidgets('Bruno, não admin, abre a rota: não encontrado', (
      tester,
    ) async {
      h.signedIn(userId: brunoId);
      h.game(() => game1(viewerId: brunoId, slotLimit: 4));
      await open(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      expect(find.text(l10nPt.commonSave), findsNothing);
    });
  });

  testWidgets('SLOT_LIMIT_BELOW_PARTICIPANTS relê as ocupadas', (tester) async {
    var participants = game1Participants();
    h.game(() => game1(slotLimit: 4, participants: participants));
    when(
      () => h.games.setSlotLimit(
        gameId: any(named: 'gameId'),
        slotLimit: any(named: 'slotLimit'),
      ),
    ).thenAnswer((_) async {
      participants = [...participants, participant(edId, 'Edu', minute: 20)];
      throw const AppException(ErrorCode.slotLimitBelowParticipants);
    });
    await open(tester);
    await decrease(tester);
    await save(tester);

    expect(find.text(l10nPt.errorSlotLimitBelowParticipants), findsOneWidget);
    expect(find.text(l10nPt.gameSlotsOccupiedHint(4)), findsOneWidget);
    expect(h.location, '/games/$game1Id/edit');
  });

  testWidgets('GAME_STARTED volta ao detalhe', (tester) async {
    when(
      () => h.games.updateGame(
        gameId: any(named: 'gameId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async => throw const AppException(ErrorCode.gameStarted));
    await open(tester);
    await tester.enterText(field('gameLocationField'), 'Ginásio Verdão');
    await save(tester);

    expect(find.text(l10nPt.errorGameStarted), findsOneWidget);
    expect(h.location, '/games/$game1Id');
  });

  testWidgets('admin com o jogo já iniciado vê o aviso', (tester) async {
    h.now = DateTime.utc(2026, 11, 21, 23, 30);
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/$game1Id/edit');

    expect(find.text(l10nPt.gameEditStarted), findsOneWidget);
    expect(find.text(l10nPt.commonSave), findsNothing);
  });

  testWidgets('validação igual à da criação', (tester) async {
    await open(tester);
    await tester.enterText(field('gameLocationField'), '');
    await save(tester);

    expect(find.text(l10nPt.gameLocationRequired), findsOneWidget);
    verifyNoSave();
  });
}
