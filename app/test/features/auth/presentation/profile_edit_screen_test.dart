import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S12 de docs/testes-referencia.md, seção 10.4 (docs/ui/telas.md, 5.8).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    when(
      () => h.profiles.updateProfile(
        name: any(named: 'name'),
        nickname: any(named: 'nickname'),
        photoPath: any(named: 'photoPath'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => h.profiles.updateContact(
        phone: any(named: 'phone'),
        phoneVisible: any(named: 'phoneVisible'),
      ),
    ).thenAnswer((_) async {});
    when(() => h.profiles.deleteAvatar(any())).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/profile');
    await h.push(tester, '/profile/edit');
  }

  Finder field(int index) => find.byType(TextFormField).at(index);
  const nameField = 0;
  const nicknameField = 1;
  const phoneField = 2;

  Switch phoneSwitch(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  Future<void> save(WidgetTester tester) async {
    final button = buttonWithText<FilledButton>(l10nPt.commonSave);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  void verifyNothingSaved() {
    verifyNever(
      () => h.profiles.updateProfile(
        name: any(named: 'name'),
        nickname: any(named: 'nickname'),
        photoPath: any(named: 'photoPath'),
      ),
    );
    verifyNever(
      () => h.profiles.updateContact(
        phone: any(named: 'phone'),
        phoneVisible: any(named: 'phoneVisible'),
      ),
    );
  }

  testWidgets('S12: com o telefone vazio, o interruptor fica desabilitado', (
    tester,
  ) async {
    await open(tester);

    expect(phoneSwitch(tester).value, isFalse);
    expect(phoneSwitch(tester).onChanged, isNull);
  });

  testWidgets('S12: apagar o telefone desliga o interruptor', (tester) async {
    h.ownProfile(phone: '+5586999991234', phoneVisible: true);
    await open(tester);

    expect(find.text('(86) 99999-1234'), findsOneWidget);
    expect(phoneSwitch(tester).value, isTrue);

    await tester.enterText(field(phoneField), '');
    await tester.pumpAndSettle();

    expect(phoneSwitch(tester).value, isFalse);
    expect(phoneSwitch(tester).onChanged, isNull);
  });

  testWidgets('S12: telefone com 9 dígitos mostra erro e não grava', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(field(phoneField), '869999123');
    await save(tester);

    expect(find.text(l10nPt.profilePhoneInvalid), findsOneWidget);
    verifyNothingSaved();
  });

  testWidgets(
    'S12: Salvar com foto nova no lugar da antiga grava na ordem do documento',
    (tester) async {
      const oldPath = 'profiles/$anaId/antiga.png';
      const newPath = 'profiles/$anaId/nova.jpg';
      final bytes = Uint8List.fromList([1, 2, 3]);
      h.ownProfile(photoPath: oldPath);
      when(() => h.picker.pick(any()))
          .thenAnswer((_) async => PickedPhoto(bytes: bytes, extension: 'jpg'));
      when(
        () => h.profiles.uploadAvatar(
          bytes: any(named: 'bytes'),
          extension: any(named: 'extension'),
        ),
      ).thenAnswer((_) async => newPath);
      await open(tester);

      await tester.tap(find.text(l10nPt.profileChangePhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.profilePhotoGallery));
      await tester.pumpAndSettle();
      await save(tester);

      verify(() => h.picker.pick(PhotoSource.gallery)).called(1);
      verifyInOrder([
        () => h.profiles.uploadAvatar(bytes: bytes, extension: 'jpg'),
        () => h.profiles.updateProfile(
          name: 'Ana Souza',
          nickname: null,
          photoPath: newPath,
        ),
        () => h.profiles.updateContact(phone: null, phoneVisible: false),
        () => h.profiles.deleteAvatar(oldPath),
      ]);
      expect(find.text(l10nPt.profileSaved), findsOneWidget);
      expect(h.location, '/profile');
    },
  );

  testWidgets('salva nome, apelido e telefone em E.164, sem tocar na foto', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(field(nameField), ' Ana Souza Lima ');
    await tester.enterText(field(nicknameField), 'Aninha');
    await tester.enterText(field(phoneField), '86999991234');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await save(tester);

    verify(
      () => h.profiles.updateProfile(
        name: 'Ana Souza Lima',
        nickname: 'Aninha',
        photoPath: null,
      ),
    ).called(1);
    verify(
      () =>
          h.profiles.updateContact(phone: '+5586999991234', phoneVisible: true),
    ).called(1);
    verifyNever(
      () => h.profiles.uploadAvatar(
        bytes: any(named: 'bytes'),
        extension: any(named: 'extension'),
      ),
    );
    verifyNever(() => h.profiles.deleteAvatar(any()));
  });

  testWidgets('apelido apagado é gravado nulo', (tester) async {
    h.ownProfile(nickname: 'Aninha');
    await open(tester);

    await tester.enterText(field(nicknameField), '');
    await save(tester);

    verify(
      () => h.profiles.updateProfile(
        name: 'Ana Souza',
        nickname: null,
        photoPath: null,
      ),
    ).called(1);
  });

  testWidgets('nome vazio e apelido longo mostram erro nos campos', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(field(nameField), '   ');
    await tester.enterText(field(nicknameField), 'A' * 31);
    await save(tester);

    expect(find.text(l10nPt.authNameRequired), findsOneWidget);
    expect(find.text(l10nPt.profileNicknameTooLong), findsOneWidget);
    verifyNothingSaved();
  });

  testWidgets('Remover foto só aparece com foto e apaga o arquivo ao salvar', (
    tester,
  ) async {
    const oldPath = 'profiles/$anaId/antiga.png';
    h.ownProfile(photoPath: oldPath);
    await open(tester);

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoRemove));
    await tester.pumpAndSettle();
    await save(tester);

    verifyInOrder([
      () => h.profiles.updateProfile(
        name: 'Ana Souza',
        nickname: null,
        photoPath: null,
      ),
      () => h.profiles.updateContact(phone: null, phoneVisible: false),
      () => h.profiles.deleteAvatar(oldPath),
    ]);
  });

  testWidgets('sem foto, a sheet não oferece Remover foto nem tem título', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.profilePhotoGallery), findsOneWidget);
    expect(find.text(l10nPt.profilePhotoCamera), findsOneWidget);
    expect(find.text(l10nPt.profilePhotoRemove), findsNothing);
  });

  testWidgets('foto de tipo recusado vira SnackBar e não é aceita', (
    tester,
  ) async {
    when(() => h.picker.pick(any()))
        .thenThrow(const AppException(ErrorCode.photoInvalidType));
    await open(tester);

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoGallery));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.errorPhotoInvalidType), findsOneWidget);
  });

  testWidgets('foto recusada pelo servidor: SnackBar, e nada é gravado', (
    tester,
  ) async {
    when(() => h.picker.pick(any())).thenAnswer(
      (_) async =>
          PickedPhoto(bytes: Uint8List.fromList([1]), extension: 'png'),
    );
    when(
      () => h.profiles.uploadAvatar(
        bytes: any(named: 'bytes'),
        extension: any(named: 'extension'),
      ),
    ).thenThrow(const AppException(ErrorCode.photoTooLarge));
    await open(tester);

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoCamera));
    await tester.pumpAndSettle();
    await save(tester);

    expect(find.text(l10nPt.errorPhotoTooLarge), findsOneWidget);
    verifyNothingSaved();
    expect(h.location, '/profile/edit');
  });

  testWidgets(
    'falha ao apagar a foto antiga é ignorada: o perfil já está salvo',
    (tester) async {
      const oldPath = 'profiles/$anaId/antiga.png';
      h.ownProfile(photoPath: oldPath);
      when(() => h.profiles.deleteAvatar(any()))
          .thenThrow(const AppException(ErrorCode.internalError));
      await open(tester);

      await tester.tap(find.text(l10nPt.profileChangePhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10nPt.profilePhotoRemove));
      await tester.pumpAndSettle();
      await save(tester);

      expect(find.text(l10nPt.profileSaved), findsOneWidget);
      expect(h.location, '/profile');
    },
  );
}
