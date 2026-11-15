import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S18 e S19 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.1).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  testWidgets('S18: sem grupos, estado vazio com os dois botões do pé', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/groups');

    expect(find.text(l10nPt.groupsEmptyTitle), findsOneWidget);
    expect(find.text(l10nPt.groupsEmptyBody), findsOneWidget);
    expect(buttonWithText<FilledButton>(l10nPt.groupsCreate), findsOneWidget);
    expect(buttonWithText<OutlinedButton>(l10nPt.groupsJoin), findsOneWidget);
  });

  testWidgets('S19: ordem alfabética, selo e solicitações só para admin', (
    tester,
  ) async {
    h.myGroups(const [
      GroupSummary(
        id: quintaId,
        name: quintaName,
        memberCount: 3,
        role: GroupRole.admin,
        pendingCount: 2,
      ),
      GroupSummary(
        id: areiaId,
        name: 'Areia',
        memberCount: 1,
        role: GroupRole.member,
        pendingCount: 0,
      ),
    ]);
    await h.pumpApp(tester, location: '/groups');

    final quintaRow = find.text(quintaName);
    final areiaRow = find.text('Areia');
    expect(
      tester.getTopLeft(areiaRow).dy,
      lessThan(tester.getTopLeft(quintaRow).dy),
    );

    expect(find.text('3 integrantes · 2 solicitações'), findsOneWidget);
    expect(find.text('1 integrante'), findsOneWidget);

    // Um selo só, na linha do Quinta.
    final badge = find.text(l10nPt.groupRoleAdmin);
    expect(badge, findsOneWidget);
    expect(
      (tester.getCenter(badge).dy - tester.getCenter(quintaRow).dy).abs(),
      lessThan(24),
    );

    // As listas tocam para abrir o detalhe.
    h.group(quinta);
    await tester.tap(quintaRow);
    await tester.pumpAndSettle();
    expect(h.location, '/groups/$quintaId');
  });

  testWidgets('os botões do pé abrem a criação e a entrada por código', (
    tester,
  ) async {
    await h.pumpApp(tester, location: '/groups');

    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupsCreate));
    await tester.pumpAndSettle();
    expect(h.location, '/groups/new');

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();
    await tester.tap(buttonWithText<OutlinedButton>(l10nPt.groupsJoin));
    await tester.pumpAndSettle();
    expect(h.location, '/groups/join');
  });
}
