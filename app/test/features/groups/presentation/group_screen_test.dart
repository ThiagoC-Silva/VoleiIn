import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/games/domain/game_models.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S25 e S26 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.4).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    when(() => h.groups.leaveGroup(any())).thenAnswer((_) async => 0);
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
  }

  Future<void> leaveAndConfirm(WidgetTester tester) async {
    // A fatia 4 pôs os jogos do grupo acima do botão: rola até ele.
    final leave = buttonWithText<OutlinedButton>(l10nPt.groupLeave);
    await tester.ensureVisible(leave);
    await tester.pumpAndSettle();
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.groupLeaveTitle(quintaName)), findsOneWidget);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupLeave));
    await tester.pumpAndSettle();
  }

  group('S25: linhas conforme o papel', () {
    testWidgets('membro comum', (tester) async {
      h.group(() => quinta(myRole: GroupRole.member));
      await open(tester);

      expect(find.text(quintaName), findsOneWidget);
      expect(find.text(l10nPt.groupMembers), findsOneWidget);
      expect(find.text(l10nPt.groupMembersSubtitle(3)), findsOneWidget);
      expect(find.text(l10nPt.groupInvite), findsOneWidget);
      expect(find.text(l10nPt.groupInviteActive), findsOneWidget);
      expect(find.text(l10nPt.groupRequests), findsNothing);
      expect(find.text(l10nPt.groupEdit), findsNothing);
      expect(buttonWithText<OutlinedButton>(l10nPt.groupLeave), findsOneWidget);
    });

    testWidgets('admin com 2 solicitações pendentes', (tester) async {
      await open(tester);

      expect(find.text(l10nPt.groupRequests), findsOneWidget);
      expect(find.text('2 solicitações pendentes'), findsOneWidget);
      expect(find.text(l10nPt.groupEdit), findsOneWidget);
      expect(find.text(l10nPt.groupEditSubtitle), findsOneWidget);
    });

    testWidgets('único membro não vê Sair do grupo', (tester) async {
      h.group(() => quinta(memberCount: 1, pendingCount: 0));
      await open(tester);

      expect(find.text(l10nPt.groupRequestsSubtitle(0)), findsOneWidget);
      expect(find.text(l10nPt.groupLeave), findsNothing);
    });

    testWidgets('convite desativado no subtítulo', (tester) async {
      h.group(() => quinta(inviteCode: null));
      await open(tester);

      expect(find.text(l10nPt.groupInviteInactive), findsOneWidget);
    });
  });

  group('S26: sair e não encontrado', () {
    testWidgets('sair, confirmar e voltar a Meus grupos', (tester) async {
      await open(tester);
      await leaveAndConfirm(tester);

      verify(() => h.groups.leaveGroup(quintaId)).called(1);
      expect(h.location, '/groups');
      expect(find.text(l10nPt.groupLeft), findsOneWidget);
    });

    testWidgets('LAST_ADMIN fica no detalhe, com o SnackBar', (tester) async {
      when(
        () => h.groups.leaveGroup(any()),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.lastAdmin));
      await open(tester);
      await leaveAndConfirm(tester);

      expect(h.location, '/groups/$quintaId');
      expect(find.text(l10nPt.errorLastAdmin), findsOneWidget);
    });

    testWidgets('Voltar na confirmação não sai', (tester) async {
      await open(tester);
      final leave = buttonWithText<OutlinedButton>(l10nPt.groupLeave);
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      await tester.tap(leave);
      await tester.pumpAndSettle();
      await tester.tap(buttonWithText<OutlinedButton>(l10nPt.commonBack));
      await tester.pumpAndSettle();

      verifyNever(() => h.groups.leaveGroup(any()));
      expect(h.location, '/groups/$quintaId');
    });

    testWidgets('grupo que o repositório não acha', (tester) async {
      h.groupNotFound(quintaId);
      await open(tester);

      expect(find.text(l10nPt.errorNotFound), findsOneWidget);
      expect(find.text(l10nPt.groupMembers), findsNothing);
    });
  });

  testWidgets('as linhas abrem integrantes, solicitações e edição', (
    tester,
  ) async {
    h.members(quintaId, quintaMembers);
    h.requests(quintaId, () => const []);
    await open(tester);

    await tester.tap(find.text(l10nPt.groupMembers));
    await tester.pumpAndSettle();
    expect(h.location, '/groups/$quintaId/members');
    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nPt.groupRequests));
    await tester.pumpAndSettle();
    expect(h.location, '/groups/$quintaId/requests');
    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10nPt.groupEdit));
    await tester.pumpAndSettle();
    expect(h.location, '/groups/$quintaId/edit');
  });

  group('S56: saída com jogos (fatia 4, etapa C)', () {
    testWidgets('confirmação com groupLeaveGamesBody e SnackBar com 2 jogos', (
      tester,
    ) async {
      when(() => h.groups.leaveGroup(any())).thenAnswer((_) async => 2);
      await open(tester);
      final leave = buttonWithText<OutlinedButton>(l10nPt.groupLeave);
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(find.textContaining(l10nPt.groupLeaveGamesBody), findsOneWidget);
      await tester.tap(buttonWithText<FilledButton>(l10nPt.groupLeave));
      await tester.pumpAndSettle();

      expect(h.location, '/groups');
      expect(find.text(l10nPt.groupLeftWithGames(2)), findsOneWidget);
    });

    testWidgets('MEMBER_IS_RECEIVER: sheet com os dois jogos, que abrem', (
      tester,
    ) async {
      when(() => h.groups.leaveGroup(any())).thenAnswer(
        (_) async => throw const AppException(
          ErrorCode.memberIsReceiver,
          gameIds: [game1Id, game2Id],
        ),
      );
      when(() => h.games.fetchGameSummaries([game1Id, game2Id])).thenAnswer(
        (_) async => [
          summary(myStatus: ParticipantStatus.active),
          summary(id: game2Id, locationName: 'Ginásio Verdão'),
        ],
      );
      h.game(game1);
      await open(tester);
      await leaveAndConfirm(tester);

      expect(find.text(l10nPt.groupLeaveBlockedTitle), findsOneWidget);
      expect(find.text(l10nPt.groupBlockedReceiverBody), findsOneWidget);
      expect(find.text('Ginásio Verdão'), findsOneWidget);
      expect(h.location, '/groups/$quintaId');

      await tester.tap(find.text('Ginásio Verdão'));
      await tester.pumpAndSettle();
      expect(h.location, '/games/$game2Id');
    });
  });
}
