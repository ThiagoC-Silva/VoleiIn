import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S35 de docs/testes-referencia.md, seção 11.6: todas as telas da
/// seção 6 do docs/ui/telas.md e a sheet do convite com a fonte do sistema em
/// 150%, num celular pequeno (360 x 640 dp), sem overflow (RNF05).
void main() {
  late TestHarness h;
  const small = Size(360, 640);
  const longName = 'Vôlei de Quinta na Areia do Rio Parnaíba';

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.myGroups(const [
      GroupSummary(
        id: quintaId,
        name: longName,
        memberCount: 12,
        role: GroupRole.admin,
        pendingCount: 10,
      ),
      GroupSummary(
        id: areiaId,
        name: 'Areia do Rio',
        memberCount: 5,
        role: GroupRole.member,
        pendingCount: 0,
      ),
    ]);
    h.group(
      () => GroupDetail(
        id: quintaId,
        name: longName,
        inviteCode: quintaCode,
        memberCount: 12,
        myRole: GroupRole.admin,
        pendingCount: 10,
      ),
    );
    h.members(
      quintaId,
      () => [
        member(anaId, 'Ana Souza de Oliveira Albuquerque', role: GroupRole.admin),
        member(brunoId, 'Brunão do vôlei de praia', day: 5),
      ],
    );
    h.requests(
      quintaId,
      () => [
        joinRequest(
          'r1',
          diegoId,
          'Diego Fernandes de Carvalho Lima',
          DateTime.utc(2026, 11, 12, 15),
        ),
      ],
    );
    when(() => h.groups.previewInvite(any())).thenAnswer(
      (_) async => const InvitePreview(
        groupId: quintaId,
        name: longName,
        isMember: false,
        hasPendingRequest: true,
      ),
    );
    when(() => h.profiles.fetchProfile(any())).thenAnswer(
      (_) async => const Profile(
        id: brunoId,
        name: 'Bruno Lima de Albuquerque',
        nickname: 'Brunão do vôlei de praia',
        displayName: 'Brunão do vôlei de praia',
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

  testWidgets('S35: Meus grupos, com dados', (tester) async {
    await open(tester, ['/groups']);
  });

  testWidgets('S35: Meus grupos, vazio', (tester) async {
    h.myGroups(const []);
    await open(tester, ['/groups']);
  });

  testWidgets('S35: Criar grupo, com os erros', (tester) async {
    await open(tester, ['/groups', '/groups/new']);
    final button = buttonWithText<FilledButton>(l10nPt.groupsCreate);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('S35: Entrar com código, etapas 1 e 2', (tester) async {
    await open(tester, ['/groups', '/groups/join']);
    await tester.enterText(find.byType(TextFormField), quintaCode);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupJoinContinue));
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.groupJoinPending), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S35: Detalhe do grupo', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId']);
  });

  testWidgets('S35: sheet do convite', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId']);
    await tester.tap(find.text(l10nPt.groupInvite));
    await tester.pumpAndSettle();
    expect(find.text(quintaCode), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S35: Integrantes e a sheet de ações', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/members']);
    await tester.tap(find.text('Brunão do vôlei de praia'));
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.groupMemberRemove), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S35: Solicitações', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/requests']);
  });

  testWidgets('S35: Editar grupo', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/edit']);
  });

  testWidgets('S35: Perfil de outra pessoa', (tester) async {
    await open(tester, ['/groups', '/people/$brunoId']);
  });
}
