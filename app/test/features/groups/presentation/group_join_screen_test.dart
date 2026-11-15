import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S22 a S24 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.3).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn(userId: diegoId);
    h.group(() => quinta(myRole: GroupRole.member));
    when(() => h.groups.previewInvite(any()))
        .thenAnswer((_) async => preview());
    when(() => h.groups.requestJoin(any())).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/join');
  }

  Future<void> continueWith(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextFormField), code);
    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupJoinContinue));
    await tester.pumpAndSettle();
  }

  Future<void> requestJoin(WidgetTester tester) async {
    await tester.tap(buttonWithText<FilledButton>(l10nPt.groupJoinRequest));
    await tester.pumpAndSettle();
  }

  void requestAnswers(ErrorCode code) {
    when(() => h.groups.requestJoin(any()))
        .thenAnswer((_) async => throw AppException(code));
  }

  group('S22: etapa 1', () {
    testWidgets('campo vazio', (tester) async {
      await open(tester);
      await continueWith(tester, '');

      expect(find.text(l10nPt.groupJoinCodeRequired), findsOneWidget);
      verifyNever(() => h.groups.previewInvite(any()));
    });

    testWidgets('11 caracteres não chamam a prévia', (tester) async {
      await open(tester);
      await continueWith(tester, 'VoleiQuinta');

      expect(find.text(l10nPt.groupJoinCodeInvalid), findsOneWidget);
      verifyNever(() => h.groups.previewInvite(any()));
    });

    testWidgets('prévia com INVITE_INVALID mostra o erro no campo', (
      tester,
    ) async {
      when(() => h.groups.previewInvite(any())).thenAnswer(
        (_) async => throw const AppException(ErrorCode.inviteInvalid),
      );
      await open(tester);
      await continueWith(tester, quintaCode);

      expect(find.text(l10nPt.errorInviteInvalid), findsOneWidget);
      expect(find.text(l10nPt.groupJoinCodeLabel), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a prévia recebe o código sem os espaços, na mesma caixa', (
      tester,
    ) async {
      await open(tester);
      await continueWith(tester, ' Volei Quinta1 ');

      verify(() => h.groups.previewInvite(quintaCode)).called(1);
      expect(find.text(quintaName), findsOneWidget);
    });
  });

  group('S23: etapa 2', () {
    testWidgets('já é membro', (tester) async {
      when(() => h.groups.previewInvite(any()))
          .thenAnswer((_) async => preview(isMember: true));
      await open(tester);
      await continueWith(tester, quintaCode);

      expect(find.text(l10nPt.groupJoinAlreadyMember), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.groupJoinOpen),
        findsOneWidget,
      );

      await tester.tap(buttonWithText<FilledButton>(l10nPt.groupJoinOpen));
      await tester.pumpAndSettle();
      expect(h.location, '/groups/$quintaId');
    });

    testWidgets('solicitação pendente', (tester) async {
      when(() => h.groups.previewInvite(any()))
          .thenAnswer((_) async => preview(hasPendingRequest: true));
      await open(tester);
      await continueWith(tester, quintaCode);

      expect(find.text(l10nPt.groupJoinPending), findsOneWidget);
      expect(find.text(l10nPt.groupJoinRequest), findsNothing);
      expect(
        buttonWithText<OutlinedButton>(l10nPt.groupJoinBackToGroups),
        findsOneWidget,
      );
    });

    testWidgets('pode pedir', (tester) async {
      await open(tester);
      await continueWith(tester, quintaCode);

      expect(find.text(l10nPt.groupJoinApprovalNeeded), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.groupJoinRequest),
        findsOneWidget,
      );
    });

    testWidgets('usar outro código volta à etapa 1 com o campo limpo', (
      tester,
    ) async {
      await open(tester);
      await continueWith(tester, quintaCode);
      await tester.tap(find.text(l10nPt.groupJoinOtherCode));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('o voltar da etapa 2 leva à etapa 1', (tester) async {
      await open(tester);
      await continueWith(tester, quintaCode);
      await tester.tap(find.byTooltip(l10nPt.commonBack));
      await tester.pumpAndSettle();

      expect(h.location, '/groups/join');
      expect(find.text(l10nPt.groupJoinCodeLabel), findsOneWidget);
    });
  });

  group('S24: pedir para entrar', () {
    testWidgets('aceito: estado pendente', (tester) async {
      await open(tester);
      await continueWith(tester, quintaCode);
      await requestJoin(tester);

      verify(() => h.groups.requestJoin(quintaCode)).called(1);
      expect(find.text(l10nPt.groupJoinPending), findsOneWidget);
      expect(find.text(l10nPt.groupJoinRequest), findsNothing);
    });

    testWidgets('JOIN_REQUEST_PENDING: estado pendente, sem SnackBar', (
      tester,
    ) async {
      requestAnswers(ErrorCode.joinRequestPending);
      await open(tester);
      await continueWith(tester, quintaCode);
      await requestJoin(tester);

      expect(find.text(l10nPt.groupJoinPending), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('ALREADY_MEMBER: estado "Já é membro"', (tester) async {
      requestAnswers(ErrorCode.alreadyMember);
      await open(tester);
      await continueWith(tester, quintaCode);
      await requestJoin(tester);

      expect(find.text(l10nPt.groupJoinAlreadyMember), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('INVITE_INVALID: volta à etapa 1 com o erro no campo', (
      tester,
    ) async {
      requestAnswers(ErrorCode.inviteInvalid);
      await open(tester);
      await continueWith(tester, quintaCode);
      await requestJoin(tester);

      expect(find.text(l10nPt.groupJoinCodeLabel), findsOneWidget);
      expect(find.text(l10nPt.errorInviteInvalid), findsOneWidget);
    });

    testWidgets('voltar aos grupos fecha a tela', (tester) async {
      await open(tester);
      await continueWith(tester, quintaCode);
      await requestJoin(tester);
      await tester.tap(
        buttonWithText<OutlinedButton>(l10nPt.groupJoinBackToGroups),
      );
      await tester.pumpAndSettle();

      expect(h.location, '/groups');
    });
  });
}
