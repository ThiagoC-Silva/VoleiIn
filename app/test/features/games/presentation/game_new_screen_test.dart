import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S38 a S41 de docs/testes-referencia.md, seção 12.6
/// (docs/ui/telas.md, 7.2; gamesNew.png e gamesNew-semPix.png).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.game(game1);
    when(() => h.games.fetchMyGroupOptions())
        .thenAnswer((_) async => [areiaOption, quintaOption]);
    when(
      () => h.games.createGame(
        groupId: any(named: 'groupId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async => game1Id);
  });

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(EditableText),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseGroup(WidgetTester tester, String name) async {
    await tapKey(tester, 'gameGroupField');
    expect(find.text(l10nPt.gameGroupSheetTitle), findsOneWidget);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(WidgetTester tester, String key, DateTime date) async {
    h.pickers.dates.add(date);
    await tapKey(tester, key);
  }

  Future<void> pickTime(
    WidgetTester tester,
    String key,
    int hour,
    int minute,
  ) async {
    h.pickers.times.add(TimeOfDay(hour: hour, minute: minute));
    await tapKey(tester, key);
  }

  /// O jogo do U10: sáb 28/11/2026, das 20:00 às 22:00, prazo 28/11 às
  /// 18:00, R$ 120,00 e 12 vagas.
  Future<void> fill(
    WidgetTester tester, {
    String location = 'Quadra do Sesc',
    String maps = '',
    int startHour = 20,
    int endHour = 22,
    int deadlineHour = 18,
  }) async {
    await tester.enterText(field('gameLocationField'), location);
    if (maps.isNotEmpty) await tester.enterText(field('gameMapsField'), maps);
    await pickDate(tester, 'gameDateField', DateTime(2026, 11, 28));
    await pickTime(tester, 'gameStartField', startHour, 0);
    await pickTime(tester, 'gameEndField', endHour, 0);
    await pickDate(tester, 'gameDeadlineDateField', DateTime(2026, 11, 28));
    await pickTime(tester, 'gameDeadlineTimeField', deadlineHour, 0);
    await tester.enterText(field('gameTotalField'), '12000');
    await tester.enterText(field('gameSlotLimitField'), '12');
    await tester.pumpAndSettle();
  }

  Future<void> create(WidgetTester tester) async {
    final button = buttonWithText<FilledButton>(l10nPt.gamesCreate);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> openFromGames(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/games');
    await h.push(tester, '/games/new');
  }

  void verifyNoCreate() => verifyNever(
    () => h.games.createGame(
      groupId: any(named: 'groupId'),
      input: any(named: 'input'),
    ),
  );

  group('S38: sem chave Pix', () {
    setUp(() {
      when(() => h.games.hasPixKey()).thenAnswer((_) async => false);
    });

    testWidgets('aviso e Criar jogo desabilitado', (tester) async {
      await openFromGames(tester);

      expect(find.text(l10nPt.gamePixNeededBody), findsOneWidget);
      expect(find.text(l10nPt.gameReceiverNotice), findsNothing);
      expect(isEnabled<FilledButton>(tester, l10nPt.gamesCreate), isFalse);
    });

    testWidgets('Cadastrar chave Pix abre /profile/pix e, ao voltar, relê', (
      tester,
    ) async {
      await openFromGames(tester);
      await tester.enterText(field('gameLocationField'), 'Quadra do Sesc');
      await tester.tap(
        buttonWithText<OutlinedButton>(l10nPt.gamePixNeededAction),
      );
      await tester.pumpAndSettle();
      expect(h.location, '/profile/pix');

      when(() => h.games.hasPixKey()).thenAnswer((_) async => true);
      h.router.pop();
      await tester.pumpAndSettle();

      expect(h.location, '/games/new');
      expect(find.text(l10nPt.gamePixNeededBody), findsNothing);
      expect(find.text(l10nPt.gameReceiverNotice), findsOneWidget);
      expect(isEnabled<FilledButton>(tester, l10nPt.gamesCreate), isTrue);
      expect(find.text('Quadra do Sesc'), findsOneWidget);
    });
  });

  group('S39: grupo escolhido', () {
    testWidgets('aberta pelo Quinta, com o Quinta escolhido', (tester) async {
      await h.pumpApp(tester, location: '/games');
      await h.push(tester, '/games/new?groupId=$quintaId');

      expect(find.text(quintaName), findsOneWidget);
      expect(find.text(l10nPt.gameGroupPlaceholder), findsNothing);
    });

    testWidgets('por Meus jogos, com um grupo só', (tester) async {
      when(() => h.games.fetchMyGroupOptions())
          .thenAnswer((_) async => [quintaOption]);
      await openFromGames(tester);

      expect(find.text(quintaName), findsOneWidget);
    });

    testWidgets('com dois grupos, criar sem escolher é erro no campo', (
      tester,
    ) async {
      await openFromGames(tester);
      expect(find.text(l10nPt.gameGroupPlaceholder), findsOneWidget);

      await fill(tester);
      await create(tester);

      expect(find.text(l10nPt.gameGroupRequired), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('a sheet lista os grupos em ordem alfabética e o Avulso', (
      tester,
    ) async {
      await openFromGames(tester);
      await tapKey(tester, 'gameGroupField');

      final areia = tester.getTopLeft(find.text('Areia do Rio')).dy;
      final quinta = tester.getTopLeft(find.text(quintaName)).dy;
      final standalone = tester.getTopLeft(find.text(l10nPt.gameStandalone)).dy;
      expect(areia, lessThan(quinta));
      expect(quinta, lessThan(standalone));
    });
  });

  group('S40: validação no app', () {
    testWidgets('campos vazios', (tester) async {
      when(() => h.games.fetchMyGroupOptions())
          .thenAnswer((_) async => [quintaOption]);
      await openFromGames(tester);
      await create(tester);

      expect(find.text(l10nPt.gameLocationRequired), findsOneWidget);
      expect(find.text(l10nPt.gameDateRequired), findsNWidgets(2));
      expect(find.text(l10nPt.gameTimeRequired), findsNWidgets(3));
      expect(find.text(l10nPt.gameTotalRequired), findsOneWidget);
      expect(find.text(l10nPt.gameSlotLimitRequired), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('prazo depois do início', (tester) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, deadlineHour: 21);
      await create(tester);

      expect(find.text(l10nPt.gameDeadlineAfterStart), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('link sem https://', (tester) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, maps: 'http://maps.app.goo.gl/x');
      await create(tester);

      expect(find.text(l10nPt.gameMapsInvalid), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('fim igual ao início', (tester) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, endHour: 20);
      await create(tester);

      expect(find.text(l10nPt.gameEndSameAsStart), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('início 23:00 e fim 01:00 mostra a dica do dia seguinte', (
      tester,
    ) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, startHour: 23, endHour: 1);

      expect(find.text('Termina dom, 29/11.'), findsOneWidget);
    });

    testWidgets('local acima de 120 caracteres e valor zero', (tester) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, location: 'a' * 121);
      await tester.enterText(field('gameTotalField'), '0');
      await create(tester);

      expect(find.text(l10nPt.gameLocationTooLong), findsOneWidget);
      expect(find.text(l10nPt.gameTotalRequired), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('início no passado, pelo relógio do aparelho', (tester) async {
      h.now = DateTime.utc(2026, 11, 29, 12);
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester);
      await create(tester);

      expect(find.text(l10nPt.gameStartInPast), findsOneWidget);
      verifyNoCreate();
    });

    testWidgets('a estimativa aparece com o valor e o limite', (tester) async {
      await openFromGames(tester);
      expect(find.text(l10nPt.gameEstimateHint), findsNothing);

      await tester.enterText(field('gameTotalField'), '12000');
      await tester.enterText(field('gameSlotLimitField'), '12');
      await tester.pumpAndSettle();

      expect(find.text('Cerca de R\$ 10,00 por pessoa'), findsOneWidget);
      expect(find.text(l10nPt.gameEstimateHint), findsOneWidget);
    });

    testWidgets('o contador não desce de 1', (tester) async {
      await openFromGames(tester);
      await tester.ensureVisible(find.byTooltip(l10nPt.gameSlotLimitIncrease));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10nPt.gameSlotLimitIncrease));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byTooltip(l10nPt.gameSlotLimitDecrease));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('S41: criar', () {
    testWidgets('avulso, com os instantes do U10, abre o detalhe', (
      tester,
    ) async {
      await openFromGames(tester);
      await chooseGroup(tester, l10nPt.gameStandalone);
      expect(find.text(l10nPt.gameGroupStandaloneHint), findsOneWidget);

      await fill(tester, location: '  Quadra do Sesc  ');
      await create(tester);

      final input =
          verify(
                () => h.games.createGame(
                  groupId: null,
                  input: captureAny(named: 'input'),
                ),
              ).captured.single
              as GameInput;
      expect(input.locationName, 'Quadra do Sesc');
      expect(input.mapsUrl, isNull);
      expect(input.startsAt, DateTime.utc(2026, 11, 28, 23));
      expect(input.endsAt, DateTime.utc(2026, 11, 29, 1));
      expect(input.cancellationDeadline, DateTime.utc(2026, 11, 28, 21));
      expect(input.totalCents, 12000);
      expect(input.slotLimit, 12);

      expect(h.location, '/games/$game1Id');
      expect(find.text(l10nPt.gameCreated), findsOneWidget);

      await tester.tap(find.byTooltip(l10nPt.commonBack));
      await tester.pumpAndSettle();
      expect(h.location, '/games');
    });

    testWidgets('com grupo, manda o group_id e o link sem espaços', (
      tester,
    ) async {
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester, maps: '  https://maps.app.goo.gl/Sesc21 ');
      await create(tester);

      final input =
          verify(
                () => h.games.createGame(
                  groupId: quintaId,
                  input: captureAny(named: 'input'),
                ),
              ).captured.single
              as GameInput;
      expect(input.mapsUrl, 'https://maps.app.goo.gl/Sesc21');
    });

    testWidgets('START_IN_PAST mantém o que foi digitado', (tester) async {
      when(
        () => h.games.createGame(
          groupId: any(named: 'groupId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer(
        (_) async => throw const AppException(ErrorCode.startInPast),
      );
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester);
      await create(tester);

      expect(h.location, '/games/new');
      expect(find.text(l10nPt.errorStartInPast), findsOneWidget);
      expect(find.text('Quadra do Sesc'), findsOneWidget);
    });

    testWidgets('RECEIVER_NEEDS_PIX_KEY relê a chave e mostra o aviso', (
      tester,
    ) async {
      when(
        () => h.games.createGame(
          groupId: any(named: 'groupId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer(
        (_) async => throw const AppException(ErrorCode.receiverNeedsPixKey),
      );
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester);
      when(() => h.games.hasPixKey()).thenAnswer((_) async => false);
      await create(tester);

      expect(find.text(l10nPt.gamePixNeededBody), findsOneWidget);
      expect(isEnabled<FilledButton>(tester, l10nPt.gamesCreate), isFalse);
    });

    testWidgets('NOT_FOUND com grupo relê os grupos', (tester) async {
      when(
        () => h.games.createGame(
          groupId: any(named: 'groupId'),
          input: any(named: 'input'),
        ),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
      await openFromGames(tester);
      await chooseGroup(tester, quintaName);
      await fill(tester);
      await create(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      verify(() => h.games.fetchMyGroupOptions()).called(greaterThan(1));
    });
  });
}
