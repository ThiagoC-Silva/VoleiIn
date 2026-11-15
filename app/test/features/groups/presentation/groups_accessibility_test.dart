import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Lista de acessibilidade de docs/ui/design-system.md, seção 8 (RNF05), nas
/// telas da seção 6 do docs/ui/telas.md. A fonte em 150% é o S35
/// (groups_text_scale_test.dart). Aqui, com as diretrizes do flutter_test:
/// área de toque de 48 x 48 dp, rótulo para o TalkBack em todo alvo de toque e
/// contraste de 4,5:1 no texto. O status do papel é sempre o texto "Admin".
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.myGroups(const [
      GroupSummary(
        id: quintaId,
        name: quintaName,
        memberCount: 3,
        role: GroupRole.admin,
        pendingCount: 2,
      ),
    ]);
    h.group(quinta);
    h.members(quintaId, quintaMembers);
    h.requests(
      quintaId,
      () => [joinRequest('r1', diegoId, 'Diego', DateTime.utc(2026, 11, 12, 15))],
    );
    when(
      () => h.groups.previewInvite(any()),
    ).thenAnswer((_) async => preview());
    when(() => h.profiles.fetchProfile(any())).thenAnswer(
      (_) async => const Profile(
        id: brunoId,
        name: 'Bruno',
        nickname: 'Brunão',
        displayName: 'Brunão',
      ),
    );
  });

  Future<void> open(WidgetTester tester, List<String> stack) async {
    await h.pumpApp(tester, location: stack.first);
    for (final location in stack.skip(1)) {
      await h.push(tester, location);
    }
    expect(h.location, stack.last);
  }

  Future<void> meetsChecklist(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('Meus grupos', (tester) async {
    await open(tester, ['/groups']);
    await meetsChecklist(tester);
  });

  testWidgets('Meus grupos, vazio', (tester) async {
    h.myGroups(const []);
    await open(tester, ['/groups']);
    await meetsChecklist(tester);
  });

  testWidgets('Criar grupo', (tester) async {
    await open(tester, ['/groups', '/groups/new']);
    await meetsChecklist(tester);
  });

  testWidgets('Entrar com código, etapas 1 e 2', (tester) async {
    await open(tester, ['/groups', '/groups/join']);
    await meetsChecklist(tester);
    await tester.enterText(find.byType(TextFormField), quintaCode);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupJoinContinue));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
  });

  testWidgets('Detalhe do grupo e a sheet do convite', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId']);
    await meetsChecklist(tester);
    await tester.tap(find.text(l10nPt.groupInvite));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
  });

  testWidgets('Integrantes e a sheet de ações', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/members']);
    await meetsChecklist(tester);
    await tester.tap(find.text('Bruno'));
    await tester.pumpAndSettle();
    await meetsChecklist(tester);
  });

  testWidgets('Solicitações', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/requests']);
    await meetsChecklist(tester);
  });

  testWidgets('Editar grupo', (tester) async {
    await open(tester, ['/groups', '/groups/$quintaId/edit']);
    await meetsChecklist(tester);
  });

  testWidgets('Perfil de outra pessoa', (tester) async {
    await open(tester, ['/groups', '/people/$brunoId']);
    await meetsChecklist(tester);
  });
}
