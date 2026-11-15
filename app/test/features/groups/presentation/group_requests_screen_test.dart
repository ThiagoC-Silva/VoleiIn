import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S32 de docs/testes-referencia.md, seção 11.6 (docs/ui/telas.md,
/// 6.7).
void main() {
  late TestHarness h;
  late List<JoinRequest> pending;

  // Diego pediu antes (qui, 12/11), Elisa depois (sex, 13/11).
  final diego = joinRequest(
    'r1',
    diegoId,
    'Diego',
    DateTime.utc(2026, 11, 12, 15),
  );
  final elisa = joinRequest(
    'r2',
    '00000000-0000-0000-0000-00000000000e',
    'Elisa',
    DateTime.utc(2026, 11, 13, 15),
  );

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    // O servidor pode devolver fora de ordem.
    pending = [elisa, diego];
    h.requests(quintaId, () => pending);
    when(
      () => h.groups.decideRequest(
        requestId: any(named: 'requestId'),
        approve: any(named: 'approve'),
      ),
    ).thenAnswer((invocation) async {
      final id = invocation.namedArguments[#requestId] as String;
      pending = pending.where((r) => r.id != id).toList();
    });
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
    await h.push(tester, '/groups/$quintaId/requests');
  }

  Finder rowButton<T extends ButtonStyleButton>(String name, String label) {
    // O botão da linha que tem o nome: o card mais próximo dos dois.
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate(
        (w) => w is Card || (w is Material && w.type == MaterialType.card),
      ),
    );
    return find.descendant(of: card.first, matching: buttonWithText<T>(label));
  }

  testWidgets('S32: ordem por created_at, com a data curta', (tester) async {
    await open(tester);

    expect(
      tester.getTopLeft(find.text('Diego')).dy,
      lessThan(tester.getTopLeft(find.text('Elisa')).dy),
    );
    expect(find.text(l10nPt.groupRequestAsked('qui, 12/11')), findsOneWidget);
    expect(find.text(l10nPt.groupRequestAsked('sex, 13/11')), findsOneWidget);
  });

  testWidgets('S32: aprovar a primeira', (tester) async {
    await open(tester);
    await tester.tap(
      rowButton<FilledButton>('Diego', l10nPt.groupRequestApprove),
    );
    await tester.pumpAndSettle();

    verify(() => h.groups.decideRequest(requestId: 'r1', approve: true))
        .called(1);
    expect(find.text('Diego'), findsNothing);
    expect(find.text(l10nPt.groupRequestApproved('Diego')), findsOneWidget);
  });

  testWidgets('S32: recusar a segunda, sem confirmação', (tester) async {
    await open(tester);
    await tester.tap(
      rowButton<OutlinedButton>('Elisa', l10nPt.groupRequestReject),
    );
    await tester.pumpAndSettle();

    verify(() => h.groups.decideRequest(requestId: 'r2', approve: false))
        .called(1);
    expect(find.text('Elisa'), findsNothing);
    expect(find.text(l10nPt.groupRequestRejected), findsOneWidget);
  });

  testWidgets('S32: REQUEST_NOT_PENDING mostra o SnackBar e relê a lista', (
    tester,
  ) async {
    when(() => h.groups.decideRequest(requestId: 'r1', approve: true))
        .thenAnswer((_) async {
          pending = [elisa];
          throw const AppException(ErrorCode.requestNotPending);
        });
    await open(tester);
    await tester.tap(
      rowButton<FilledButton>('Diego', l10nPt.groupRequestApprove),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorRequestNotPending), findsOneWidget);
    expect(find.text('Diego'), findsNothing);
    expect(find.text('Elisa'), findsOneWidget);
  });

  testWidgets('S32: enviando bloqueia só a linha tocada', (tester) async {
    when(() => h.groups.decideRequest(requestId: 'r1', approve: true))
        .thenAnswer((_) => Future.delayed(const Duration(seconds: 1)));
    await open(tester);
    await tester.tap(
      rowButton<FilledButton>('Diego', l10nPt.groupRequestApprove),
    );
    await tester.pump();

    final reject = tester.widget<OutlinedButton>(
      rowButton<OutlinedButton>('Diego', l10nPt.groupRequestReject),
    );
    expect(reject.onPressed, isNull);
    final other = tester.widget<FilledButton>(
      rowButton<FilledButton>('Elisa', l10nPt.groupRequestApprove),
    );
    expect(other.onPressed, isNotNull);
    await tester.pumpAndSettle();
  });

  testWidgets('sem solicitações, estado vazio', (tester) async {
    pending = [];
    await open(tester);

    expect(find.text(l10nPt.groupRequestsEmptyTitle), findsOneWidget);
    expect(find.text(l10nPt.groupRequestsEmptyBody), findsOneWidget);
  });

  testWidgets('tocar no nome abre o perfil de quem pediu', (tester) async {
    when(() => h.profiles.fetchProfile(any()))
        .thenAnswer((_) async => throw const AppException(ErrorCode.notFound));
    await open(tester);
    await tester.tap(find.text('Diego'));
    await tester.pumpAndSettle();

    expect(h.location, '/people/$diegoId');
  });

  testWidgets('S32: Bruno, membro, vê o estado "não encontrado"', (
    tester,
  ) async {
    h.signedIn(userId: brunoId);
    h.group(() => quinta(myRole: GroupRole.member));
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId/requests');

    expect(find.text(l10nPt.errorNotFound), findsOneWidget);
    expect(find.text('Diego'), findsNothing);
  });
}
