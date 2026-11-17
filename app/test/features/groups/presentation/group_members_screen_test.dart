import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';
import 'package:voleiin/shared/widgets/list_card.dart';

import '../../../helpers/games_fixtures.dart';
import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S29 a S31 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.6).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    h.members(quintaId, quintaMembers);
    when(
      () => h.groups.setRole(
        groupId: any(named: 'groupId'),
        userId: any(named: 'userId'),
        role: any(named: 'role'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => h.groups.removeMember(
        groupId: any(named: 'groupId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => 0);
    when(() => h.profiles.fetchProfile(any())).thenAnswer(
      (_) async =>
          const Profile(id: anaId, name: 'Ana Souza', displayName: 'Ana Souza'),
    );
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
    await h.push(tester, '/groups/$quintaId/members');
  }

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> tapOption(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  final you = l10nPt.groupMemberYou('Ana');

  testWidgets('S29: admins primeiro, cada bloco em ordem alfabética', (
    tester,
  ) async {
    await open(tester);

    final ana = tester.getTopLeft(find.text(you)).dy;
    final bruno = tester.getTopLeft(find.text('Bruno')).dy;
    final carla = tester.getTopLeft(find.text('Carla')).dy;
    expect(ana, lessThan(bruno));
    expect(bruno, lessThan(carla));

    final badge = find.text(l10nPt.groupRoleAdmin);
    expect(badge, findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(of: find.text(you), matching: find.byType(ListRow)),
        matching: badge,
      ),
      findsOneWidget,
    );
    expect(find.text(l10nPt.groupMemberJoinedAt('05/11/2026')), findsOneWidget);
  });

  testWidgets('S29: admin toca em outra pessoa e abre a sheet de ações', (
    tester,
  ) async {
    await open(tester);
    await tapRow(tester, 'Bruno');

    expect(find.text(l10nPt.groupMemberViewProfile), findsOneWidget);
    expect(find.text(l10nPt.groupMemberMakeAdmin), findsOneWidget);
    expect(find.text(l10nPt.groupMemberMakeMember), findsNothing);
    expect(find.text(l10nPt.groupMemberRemove), findsOneWidget);
  });

  testWidgets('S29: admin toca em si e vê Deixar de ser admin', (tester) async {
    await open(tester);
    await tapRow(tester, you);

    expect(find.text(l10nPt.groupStepDown), findsOneWidget);
    expect(find.text(l10nPt.groupMemberRemove), findsNothing);
  });

  testWidgets('S29: sheet de outro admin oferece Deixar como membro', (
    tester,
  ) async {
    h.members(quintaId, () => quintaMembers(brunoRole: GroupRole.admin));
    await open(tester);
    await tapRow(tester, 'Bruno');

    expect(find.text(l10nPt.groupMemberMakeMember), findsOneWidget);
    expect(find.text(l10nPt.groupMemberMakeAdmin), findsNothing);
  });

  testWidgets('S29: Ver perfil abre o perfil da pessoa', (tester) async {
    await open(tester);
    await tapRow(tester, 'Bruno');
    await tapOption(tester, l10nPt.groupMemberViewProfile);

    expect(h.location, '/people/$brunoId');
  });

  group('S30: Bruno, membro', () {
    setUp(() {
      h.signedIn(userId: brunoId);
      h.group(() => quinta(myRole: GroupRole.member));
    });

    testWidgets('toca na Ana e abre o perfil dela', (tester) async {
      await open(tester);
      await tapRow(tester, 'Ana');

      expect(h.location, '/people/$anaId');
    });

    testWidgets('toca em si e nada acontece', (tester) async {
      await open(tester);
      await tapRow(tester, l10nPt.groupMemberYou('Bruno'));

      expect(h.location, '/groups/$quintaId/members');
      expect(find.text(l10nPt.groupStepDown), findsNothing);
      expect(find.text(l10nPt.groupMemberViewProfile), findsNothing);
    });
  });

  group('S31: ações do admin', () {
    testWidgets('tornar Bruno admin', (tester) async {
      await open(tester);
      await tapRow(tester, 'Bruno');
      await tapOption(tester, l10nPt.groupMemberMakeAdmin);

      verify(
        () => h.groups.setRole(
          groupId: quintaId,
          userId: brunoId,
          role: GroupRole.admin,
        ),
      ).called(1);
      expect(find.text(l10nPt.groupMemberNowAdmin('Bruno')), findsOneWidget);
    });

    testWidgets('remover Carla, depois de confirmar', (tester) async {
      var list = quintaMembers();
      h.members(quintaId, () => list);
      when(() => h.groups.removeMember(groupId: quintaId, userId: carlaId))
          .thenAnswer((_) async {
            list = list.where((m) => m.userId != carlaId).toList();
            return 0;
          });
      await open(tester);
      await tapRow(tester, 'Carla');
      await tapOption(tester, l10nPt.groupMemberRemove);
      expect(find.text(l10nPt.groupMemberRemoveTitle('Carla')), findsOneWidget);
      await tester.tap(
        buttonWithText<FilledButton>(l10nPt.groupMemberRemoveConfirm),
      );
      await tester.pumpAndSettle();

      verify(() => h.groups.removeMember(groupId: quintaId, userId: carlaId))
          .called(1);
      expect(find.text(l10nPt.groupMemberRemoved('Carla')), findsOneWidget);
      expect(find.text('Carla'), findsNothing);
    });

    testWidgets('Ana, única admin, deixa de ser admin e recebe LAST_ADMIN', (
      tester,
    ) async {
      when(
        () => h.groups.setRole(
          groupId: quintaId,
          userId: anaId,
          role: GroupRole.member,
        ),
      ).thenAnswer((_) async => throw const AppException(ErrorCode.lastAdmin));
      await open(tester);
      await tapRow(tester, you);
      await tapOption(tester, l10nPt.groupStepDown);
      expect(find.text(l10nPt.groupStepDownTitle), findsOneWidget);
      await tester.tap(buttonWithText<FilledButton>(l10nPt.groupStepDown));
      await tester.pumpAndSettle();

      verify(
        () => h.groups.setRole(
          groupId: quintaId,
          userId: anaId,
          role: GroupRole.member,
        ),
      ).called(1);
      expect(find.text(l10nPt.errorLastAdmin), findsOneWidget);
    });
  });

  testWidgets('quem não é membro vê o estado "não encontrado"', (tester) async {
    when(() => h.groups.fetchMembers(quintaId))
        .thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId/members');

    expect(find.text(l10nPt.errorNotFound), findsOneWidget);
  });

  testWidgets('S57: remover o Bruno com MEMBER_IS_ONLY_GAME_ADMIN', (
    tester,
  ) async {
    when(() => h.groups.removeMember(groupId: quintaId, userId: brunoId))
        .thenAnswer(
          (_) async => throw const AppException(
            ErrorCode.memberIsOnlyGameAdmin,
            gameIds: [game1Id],
          ),
        );
    when(() => h.games.fetchGameSummaries([game1Id]))
        .thenAnswer((_) async => [summary()]);
    await open(tester);
    await tester.tap(find.text('Bruno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.groupMemberRemove));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(l10nPt.groupMemberRemoveGamesBody('Bruno')),
      findsOneWidget,
    );
    await tester.tap(
      buttonWithText<FilledButton>(l10nPt.groupMemberRemoveConfirm),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.groupRemoveBlockedTitle('Bruno')), findsOneWidget);
    expect(
      find.text(l10nPt.groupRemoveBlockedOnlyAdminBody('Bruno')),
      findsOneWidget,
    );
    expect(find.text('Quadra do Sesc'), findsOneWidget);
  });
}
