import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S27 e S28 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.5).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    when(() => h.groups.invalidateInvite(any())).thenAnswer((_) async {});
  });

  Future<void> openSheet(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
    await tester.tap(find.text(l10nPt.groupInvite));
    await tester.pumpAndSettle();
    expect(find.text(l10nPt.groupInviteTitle), findsOneWidget);
  }

  group('S27: conforme o papel e o convite', () {
    testWidgets('membro com código', (tester) async {
      h.group(() => quinta(myRole: GroupRole.member));
      await openSheet(tester);

      expect(find.text(quintaCode), findsOneWidget);
      expect(
        buttonWithText<FilledButton>(l10nPt.groupInviteShare),
        findsOneWidget,
      );
      expect(
        buttonWithText<OutlinedButton>(l10nPt.groupInviteCopy),
        findsOneWidget,
      );
      expect(find.text(l10nPt.groupInviteRegenerate), findsNothing);
      expect(find.text(l10nPt.groupInviteDisable), findsNothing);
    });

    testWidgets('admin com código', (tester) async {
      h.group(quinta);
      await openSheet(tester);

      expect(find.text(quintaCode), findsOneWidget);
      expect(
        buttonWithText<TextButton>(l10nPt.groupInviteRegenerate),
        findsOneWidget,
      );
      expect(
        buttonWithText<TextButton>(l10nPt.groupInviteDisable),
        findsOneWidget,
      );
    });

    testWidgets('gerar novo código, confirmar e ver o código novo', (
      tester,
    ) async {
      var code = quintaCode;
      h.group(() => quinta(inviteCode: code));
      when(() => h.groups.regenerateInvite(quintaId)).thenAnswer((_) async {
        code = 'NovoCodigo12';
        return code;
      });
      await openSheet(tester);

      await tester.tap(
        buttonWithText<TextButton>(l10nPt.groupInviteRegenerate),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.groupInviteRegenerateTitle), findsOneWidget);
      await tester.tap(
        buttonWithText<FilledButton>(l10nPt.groupInviteRegenerate),
      );
      await tester.pumpAndSettle();

      verify(() => h.groups.regenerateInvite(quintaId)).called(1);
      expect(find.text(l10nPt.groupInviteTitle), findsOneWidget);
      expect(find.text('NovoCodigo12'), findsOneWidget);
      expect(find.text(l10nPt.groupInviteRegenerated), findsOneWidget);
    });

    testWidgets('desativar, confirmar e ver o estado desativado', (
      tester,
    ) async {
      String? code = quintaCode;
      h.group(() => quinta(inviteCode: code));
      when(() => h.groups.invalidateInvite(quintaId)).thenAnswer((_) async {
        code = null;
      });
      await openSheet(tester);

      await tester.tap(buttonWithText<TextButton>(l10nPt.groupInviteDisable));
      await tester.pumpAndSettle();
      expect(find.text(l10nPt.groupInviteDisableTitle), findsOneWidget);
      await tester.tap(
        buttonWithText<FilledButton>(l10nPt.groupInviteDisableConfirm),
      );
      await tester.pumpAndSettle();

      verify(() => h.groups.invalidateInvite(quintaId)).called(1);
      expect(find.text(l10nPt.groupInviteOff), findsOneWidget);
      expect(find.text(l10nPt.groupInviteDisabled), findsOneWidget);
    });

    testWidgets('membro com o convite desativado', (tester) async {
      h.group(() => quinta(myRole: GroupRole.member, inviteCode: null));
      await openSheet(tester);

      expect(find.text(l10nPt.groupInviteOff), findsOneWidget);
      expect(find.text(l10nPt.groupInviteAskAdmin), findsOneWidget);
      expect(find.text(l10nPt.groupInviteGenerate), findsNothing);
      expect(find.text(l10nPt.groupInviteShare), findsNothing);
    });

    testWidgets('admin com o convite desativado gera sem confirmação', (
      tester,
    ) async {
      String? code;
      h.group(() => quinta(inviteCode: code));
      when(() => h.groups.regenerateInvite(quintaId)).thenAnswer((_) async {
        code = quintaCode;
        return quintaCode;
      });
      await openSheet(tester);

      await tester.tap(
        buttonWithText<FilledButton>(l10nPt.groupInviteGenerate),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.groupInviteRegenerateTitle), findsNothing);
      verify(() => h.groups.regenerateInvite(quintaId)).called(1);
      expect(find.text(quintaCode), findsOneWidget);
    });

    testWidgets('NOT_GROUP_ADMIN passa à versão de membro', (tester) async {
      var role = GroupRole.admin;
      h.group(() => quinta(myRole: role));
      when(() => h.groups.invalidateInvite(quintaId)).thenAnswer((_) async {
        role = GroupRole.member;
        throw const AppException(ErrorCode.notGroupAdmin);
      });
      await openSheet(tester);

      await tester.tap(buttonWithText<TextButton>(l10nPt.groupInviteDisable));
      await tester.pumpAndSettle();
      await tester.tap(
        buttonWithText<FilledButton>(l10nPt.groupInviteDisableConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10nPt.errorNotGroupAdmin), findsOneWidget);
      expect(find.text(l10nPt.groupInviteDisable), findsNothing);
      expect(find.text(quintaCode), findsOneWidget);
    });
  });

  group('S28: copiar e compartilhar', () {
    testWidgets('copiar leva só o código', (tester) async {
      h.group(quinta);
      final copied = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await openSheet(tester);

      await tester.tap(buttonWithText<OutlinedButton>(l10nPt.groupInviteCopy));
      await tester.pumpAndSettle();

      expect(copied, [quintaCode]);
      expect(find.text(l10nPt.groupInviteCopied), findsOneWidget);
    });

    testWidgets('compartilhar leva o texto com o nome e o código', (
      tester,
    ) async {
      h.group(quinta);
      await openSheet(tester);

      await tester.tap(buttonWithText<FilledButton>(l10nPt.groupInviteShare));
      await tester.pumpAndSettle();

      verify(
        () => h.sharer.shareText(
          l10nPt.groupInviteShareText(quintaName, quintaCode),
        ),
      ).called(1);
      expect(
        l10nPt.groupInviteShareText(quintaName, quintaCode),
        endsWith(': $quintaCode'),
      );
    });
  });
}
