import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/core/env.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/shared/widgets/list_card.dart';

import '../test/helpers/test_app.dart';

/// Cenários L12 a L14 de docs/testes-referencia.md, seção 11.6.
///
/// Roda no emulador, contra o Supabase local com o seed (docs/setup.md, 8),
/// pelos scripts/ (setup.md, 3.1). Cada fluxo deixa o seed como encontrou: o
/// Diego sai do Vôlei de Quinta no fim do L12 (a solicitação aprovada fica no
/// histórico, como as do C13), o L13 exclui o grupo que criou e o L14 devolve
/// a Carla a membro.
///
/// ```bash
/// scripts/integration-test.sh integration_test/groups_flow_test.dart
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'voleiin123';
  const quinta = 'Vôlei de Quinta';

  GoTrueClient auth() => Supabase.instance.client.auth;

  setUpAll(() async {
    Env.ensureComplete();
    initTimeZones();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  setUp(() async {
    await auth().signOut();
  });

  /// Entra direto pelo Supabase Auth e abre o app do zero, já com a sessão.
  Future<void> openAs(WidgetTester tester, String person) async {
    await auth().signOut();
    await auth().signInWithPassword(
      email: '$person@voleiin.test',
      password: password,
    );
    await tester.pumpWidget(Container());
    await tester.pumpWidget(const ProviderScope(child: VoleiInApp()));
    await tester.pumpAndSettle();
  }

  /// Bombeia quadros até o [finder] aparecer: as chamadas ao Supabase local
  /// levam tempo de verdade.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    final onScreen = find
        .byType(Text)
        .evaluate()
        .map(
          (e) =>
              (e.widget as Text).data ??
              (e.widget as Text).textSpan?.toPlainText(),
        )
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .join(' | ');
    throw TestFailure(
      'Não apareceu em ${timeout.inSeconds} s: $finder\nNa tela: $onScreen',
    );
  }

  /// Bombeia quadros até o [finder] sumir.
  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    throw TestFailure('Não sumiu em 20 s: $finder');
  }

  /// Toca quando o alvo já recebe o toque (account_flow_test.dart).
  Future<void> tapReady(WidgetTester tester, Finder finder) async {
    await pumpUntil(tester, finder);
    await tester.ensureVisible(finder);
    await pumpUntil(tester, finder.hitTestable());
    await tester.tap(finder);
  }

  Finder button<T extends Widget>(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(T));

  Future<void> openGroupsTab(WidgetTester tester) async {
    await tapReady(tester, find.text(l10nPt.navGroups).last);
    await pumpUntil(tester, find.text(l10nPt.groupsCreate));
  }

  Future<void> openGroup(WidgetTester tester, String name) async {
    await openGroupsTab(tester);
    await tapReady(tester, find.text(name));
    await pumpUntil(tester, find.text(l10nPt.groupMembers));
  }

  /// Se a linha da lista com o nome tem o selo Admin.
  bool hasAdminBadge(String name) => find
      .descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(ListRow)),
        matching: find.text(l10nPt.groupRoleAdmin),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('L12: Diego pede, Ana aprova, Diego entra e depois sai', (
    tester,
  ) async {
    // Diego pede para entrar com o código.
    await openAs(tester, 'diego');
    await openGroupsTab(tester);
    await tapReady(tester, button<OutlinedButton>(l10nPt.groupsJoin));
    await pumpUntil(tester, find.text(l10nPt.groupJoinCodeLabel));
    await tester.enterText(find.byType(TextFormField), 'VoleiQuinta1');
    await tapReady(tester, button<FilledButton>(l10nPt.groupJoinContinue));
    await tapReady(tester, button<FilledButton>(l10nPt.groupJoinRequest));
    await pumpUntil(tester, find.text(l10nPt.groupJoinPending));

    // Ana aprova em Solicitações.
    await openAs(tester, 'ana');
    await openGroup(tester, quinta);
    await tapReady(tester, find.text(l10nPt.groupRequests));
    await pumpUntil(tester, find.text('Diego'));
    await tapReady(tester, button<FilledButton>(l10nPt.groupRequestApprove));
    await pumpUntil(tester, find.text(l10nPt.groupRequestApproved('Diego')));

    // Diego vê o grupo e os integrantes.
    await openAs(tester, 'diego');
    await openGroup(tester, quinta);
    await tapReady(tester, find.text(l10nPt.groupMembers));
    await pumpUntil(tester, find.text('Ana'));
    expect(find.text('Brunão'), findsOneWidget);
    expect(find.text('Carlinha'), findsOneWidget);
    expect(find.text(l10nPt.groupMemberYou('Diego')), findsOneWidget);

    // Diego sai, e o grupo some da lista.
    await tapReady(tester, find.byTooltip(l10nPt.commonBack));
    await tapReady(tester, button<OutlinedButton>(l10nPt.groupLeave));
    await tapReady(tester, button<FilledButton>(l10nPt.groupLeave));
    await pumpUntil(tester, find.text(l10nPt.groupLeft));
    await pumpUntil(tester, find.text(l10nPt.groupsEmptyTitle));
    expect(find.text(quinta), findsNothing);
  });

  testWidgets('L13: Ana cria, gera um novo código e exclui o grupo', (
    tester,
  ) async {
    final now = DateTime.now();
    final name =
        'L13 ${formatDate(now.toUtc())} ${formatTime(now.toUtc())}:'
        '${now.second.toString().padLeft(2, '0')}';
    await openAs(tester, 'ana');
    await openGroupsTab(tester);

    await tapReady(tester, button<FilledButton>(l10nPt.groupsCreate));
    await pumpUntil(tester, find.text(l10nPt.groupNameLabel));
    await tester.enterText(find.byType(TextFormField), name);
    await tapReady(tester, button<FilledButton>(l10nPt.groupsCreate));
    await pumpUntil(tester, find.text(l10nPt.groupCreated));
    await pumpUntil(tester, find.text(l10nPt.groupMembers));

    // O código muda na sheet.
    await tapReady(tester, find.text(l10nPt.groupInvite));
    await pumpUntil(tester, find.text(l10nPt.groupInviteTitle));
    final codePattern = RegExp(r'^[0-9A-Za-z]{12}$');
    String currentCode() => find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .firstWhere(codePattern.hasMatch);
    final before = currentCode();
    await tapReady(tester, button<TextButton>(l10nPt.groupInviteRegenerate));
    await tapReady(tester, button<FilledButton>(l10nPt.groupInviteRegenerate));
    await pumpUntil(tester, find.text(l10nPt.groupInviteRegenerated));
    await pumpUntilGone(tester, find.text(before));
    expect(currentCode(), isNot(before));

    // Fecha a sheet e exclui o grupo.
    await tester.tapAt(const Offset(20, 120));
    await pumpUntilGone(tester, find.text(l10nPt.groupInviteTitle));
    await tapReady(tester, find.text(l10nPt.groupEdit));
    await tapReady(tester, button<OutlinedButton>(l10nPt.groupDelete));
    await tapReady(tester, button<FilledButton>(l10nPt.groupDelete));
    await pumpUntil(tester, find.text(l10nPt.groupDeleted));
    await pumpUntil(tester, find.text(quinta));
    expect(find.text(name), findsNothing);
  });

  testWidgets('L14: Ana torna a Carla admin e depois a deixa como membro', (
    tester,
  ) async {
    await openAs(tester, 'ana');
    await openGroup(tester, quinta);
    await tapReady(tester, find.text(l10nPt.groupMembers));
    await pumpUntil(tester, find.text('Carlinha'));
    expect(hasAdminBadge('Carlinha'), isFalse);

    await tapReady(tester, find.text('Carlinha'));
    await tapReady(tester, find.text(l10nPt.groupMemberMakeAdmin));
    await pumpUntil(tester, find.text(l10nPt.groupMemberNowAdmin('Carlinha')));
    await tester.pumpAndSettle();
    expect(hasAdminBadge('Carlinha'), isTrue);

    await tapReady(tester, find.text('Carlinha'));
    await tapReady(tester, find.text(l10nPt.groupMemberMakeMember));
    await pumpUntil(tester, find.text(l10nPt.groupMemberNowMember('Carlinha')));
    await tester.pumpAndSettle();
    expect(hasAdminBadge('Carlinha'), isFalse);
  });
}
