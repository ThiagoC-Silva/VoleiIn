import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/photo_picker.dart';

import '../../../helpers/groups_fixtures.dart';
import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S20 e S21 de docs/testes-referencia.md, seção 11.6
/// (docs/ui/telas.md, 6.2).
void main() {
  late TestHarness h;
  const newPath = 'groups/$quintaId/nova.jpg';

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.group(quinta);
    when(() => h.groups.createGroup(any())).thenAnswer((_) async => quintaId);
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
    when(() => h.picker.pick(PhotoSource.gallery))
        .thenAnswer((_) async => pickedPhoto);
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/groups');
    await h.push(tester, '/groups/new');
  }

  Future<void> create(WidgetTester tester) async {
    final button = buttonWithText<FilledButton>(l10nPt.groupsCreate);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> choosePhoto(WidgetTester tester) async {
    await tester.tap(find.text(l10nPt.groupChoosePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoGallery));
    await tester.pumpAndSettle();
  }

  testWidgets('S20: nome vazio mostra o erro e não chama o servidor', (
    tester,
  ) async {
    await open(tester);
    await create(tester);

    expect(find.text(l10nPt.groupNameRequired), findsOneWidget);
    verifyNever(() => h.groups.createGroup(any()));
  });

  testWidgets('S20: nome com 61 caracteres mostra o erro', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), 'a' * 61);
    await create(tester);

    expect(find.text(l10nPt.groupNameTooLong), findsOneWidget);
    verifyNever(() => h.groups.createGroup(any()));
  });

  testWidgets('S20: criar sem foto abre o detalhe, sem voltar à criação', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField), '  $quintaName ');
    await create(tester);

    verify(() => h.groups.createGroup(quintaName)).called(1);
    verifyNever(
      () => h.groups.updateGroup(
        groupId: any(named: 'groupId'),
        name: any(named: 'name'),
        photoPath: any(named: 'photoPath'),
      ),
    );
    expect(h.location, '/groups/$quintaId');
    expect(find.text(l10nPt.groupCreated), findsOneWidget);

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();
    expect(h.location, '/groups');
  });

  testWidgets('S21: com foto, cria, envia a foto e grava o caminho', (
    tester,
  ) async {
    await open(tester);
    await choosePhoto(tester);
    await tester.enterText(find.byType(TextFormField), quintaName);
    await create(tester);

    verifyInOrder([
      () => h.groups.createGroup(quintaName),
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
    ]);
    expect(h.location, '/groups/$quintaId');
    expect(find.text(l10nPt.groupCreated), findsOneWidget);
  });

  testWidgets('S21: se a foto falha, abre o detalhe com o aviso', (
    tester,
  ) async {
    when(
      () => h.groups.uploadGroupPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
        extension: any(named: 'extension'),
      ),
    ).thenAnswer(
      (_) async => throw const AppException(ErrorCode.photoTooLarge),
    );
    await open(tester);
    await choosePhoto(tester);
    await tester.enterText(find.byType(TextFormField), quintaName);
    await create(tester);

    expect(h.location, '/groups/$quintaId');
    expect(find.text(l10nPt.groupCreatedPhotoFailed), findsOneWidget);
  });

  testWidgets('erro no create_group fica na tela, com o nome', (tester) async {
    when(
      () => h.groups.createGroup(any()),
    ).thenAnswer((_) async => throw const AppException(ErrorCode.noConnection));
    await open(tester);
    await tester.enterText(find.byType(TextFormField), quintaName);
    await create(tester);

    expect(h.location, '/groups/new');
    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);
    expect(find.text(quintaName), findsWidgets);
  });
}
