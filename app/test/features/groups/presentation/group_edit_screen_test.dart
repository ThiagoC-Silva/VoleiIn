import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S33 de docs/testes-referencia.md, seção 11.6 (docs/ui/telas.md,
/// 6.8).
void main() {
  late TestHarness h;
  const oldPath = 'groups/$quintaId/antiga.jpg';
  const newPath = 'groups/$quintaId/nova.jpg';

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(() => quinta(photoPath: oldPath));
    when(
      () => h.groups.uploadGroupPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer((_) async => newPath);
    when(
      () => h.groups.updateGroup(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        photoPath: any(named: 'photoPath'),
      ),
    ).thenAnswer((_) async {});
    when(() => h.groups.deleteGroupPhoto(any())).thenAnswer((_) async {});
    when(() => h.groups.archiveGroup(any())).thenAnswer((_) async {});
    when(
      () => h.picker.pick(PhotoSource.gallery),
    ).thenAnswer((_) async => pickedPhoto);
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/$quintaId');
    await h.push(tester, '/groups/$quintaId/edit');
  }

  Future<void> tapButton<T extends ButtonStyleButton>(
    WidgetTester tester,
    String label,
  ) async {
    final button = buttonWithText<T>(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> deleteAndConfirm(WidgetTester tester) async {
    await tapButton<OutlinedButton>(tester, l10nPt.groupDelete);
    expect(find.text(l10nPt.groupDeleteTitle(quintaName)), findsOneWidget);
    await tapButton<FilledButton>(tester, l10nPt.groupDelete);
  }

  testWidgets('S33: salvar com foto nova no lugar da antiga', (tester) async {
    await open(tester);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      quintaName,
    );
    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoGallery));
    await tester.pumpAndSettle();
    await tapButton<FilledButton>(tester, l10nPt.commonSave);

    verifyInOrder([
      () => h.groups.uploadGroupPhoto(
        groupId: quintaId,
        bytes: pickedPhoto.bytes,
        extension: 'jpg',
      ),
      () => h.groups.updateGroup(
        groupId: quintaId,
        name: quintaName,
        photoPath: newPath,
      ),
      () => h.groups.deleteGroupPhoto(oldPath),
    ]);
    expect(h.location, '/groups/$quintaId');
    expect(find.text(l10nPt.groupSaved), findsOneWidget);
  });

  testWidgets('remover a foto só vale no Salvar, com o caminho nulo', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoRemove));
    await tester.pumpAndSettle();
    verifyNever(
      () => h.groups.updateGroup(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        photoPath: any(named: 'photoPath'),
      ),
    );
    await tapButton<FilledButton>(tester, l10nPt.commonSave);

    verifyInOrder([
      () => h.groups.updateGroup(
        groupId: quintaId,
        name: quintaName,
        photoPath: null,
      ),
      () => h.groups.deleteGroupPhoto(oldPath),
    ]);
  });

  testWidgets('nome vazio mostra o erro e não chama o servidor', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), '   ');
    await tapButton<FilledButton>(tester, l10nPt.commonSave);

    expect(find.text(l10nPt.groupNameRequired), findsOneWidget);
    verifyNever(
      () => h.groups.updateGroup(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        photoPath: any(named: 'photoPath'),
      ),
    );
  });

  testWidgets('S33: excluir, confirmar e voltar a Meus grupos', (
    tester,
  ) async {
    await open(tester);
    await deleteAndConfirm(tester);

    verify(() => h.groups.archiveGroup(quintaId)).called(1);
    expect(h.location, '/groups');
    expect(find.text(l10nPt.groupDeleted), findsOneWidget);
  });

  testWidgets('S33: GROUP_HAS_ACTIVE_GAMES mantém o grupo', (tester) async {
    when(() => h.groups.archiveGroup(any())).thenAnswer(
      (_) async => throw const AppException(ErrorCode.groupHasActiveGames),
    );
    await open(tester);
    await deleteAndConfirm(tester);

    expect(h.location, '/groups/$quintaId/edit');
    expect(find.text(l10nPt.errorGroupHasActiveGames), findsOneWidget);
  });

  testWidgets('S33: Bruno, membro, vê o estado "não encontrado"', (
    tester,
  ) async {
    h.signedIn(userId: brunoId);
    h.group(() => quinta(myRole: GroupRole.member));
    await open(tester);

    expect(find.text(l10nPt.errorNotFound), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
