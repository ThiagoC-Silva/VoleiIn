import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/format/image_type.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/presentation/profile_edit_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S12 de docs/testes-referencia.md, seção 10.4 (RN101, RN106).
void main() {
  setUpAll(registerFakes);

  late MockProfileRepository profile;
  late MockPhotoPicker picker;

  setUp(() {
    profile = MockProfileRepository();
    picker = MockPhotoPicker();
    when(() => profile.signedPhotoUrl(any())).thenAnswer((_) async => 'https://x/y.png');
    when(
      () => profile.updateProfile(
        name: any(named: 'name'),
        nickname: any(named: 'nickname'),
        photoPath: any(named: 'photoPath'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => profile.updatePrivate(
        phone: any(named: 'phone'),
        phoneVisible: any(named: 'phoneVisible'),
      ),
    ).thenAnswer((_) async {});
    when(() => profile.deletePhoto(any())).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, OwnProfile data) {
    when(() => profile.fetchOwn()).thenAnswer((_) async => data);
    return pumpRouterApp(
      tester,
      initialLocation: Routes.profileEditPath,
      overrides: [
        profileRepositoryProvider.overrideWithValue(profile),
        photoPickerProvider.overrideWithValue(picker),
      ],
      screens: {Routes.profileEdit: (_) => const ProfileEditScreen()},
    );
  }

  Switch phoneSwitch(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  Finder phoneField() => find.byType(TextFormField).at(2);

  Finder save() => find.widgetWithText(FilledButton, l10nPt.commonSave);

  testWidgets('S12a: com o telefone vazio, o interruptor fica desabilitado', (
    tester,
  ) async {
    await pump(tester, ownProfile());
    expect(phoneSwitch(tester).onChanged, isNull);
  });

  testWidgets('S12b: apagar o telefone desliga o interruptor', (tester) async {
    await pump(tester, ownProfile(phone: '+5586999991234', phoneVisible: true));
    expect(phoneSwitch(tester).value, isTrue);

    await tester.enterText(phoneField(), '');
    await tester.pumpAndSettle();

    expect(phoneSwitch(tester).value, isFalse);
    expect(phoneSwitch(tester).onChanged, isNull);
  });

  testWidgets('S12c: telefone com 9 dígitos dá erro', (tester) async {
    await pump(tester, ownProfile());
    await tester.enterText(phoneField(), '869999912');
    await tester.tap(save());
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.profilePhoneInvalid), findsOneWidget);
    verifyNever(
      () => profile.updateProfile(
        name: any(named: 'name'),
        nickname: any(named: 'nickname'),
        photoPath: any(named: 'photoPath'),
      ),
    );
  });

  testWidgets('S12d: foto nova no lugar da antiga grava nesta ordem', (
    tester,
  ) async {
    const oldPath = 'profiles/$anaId/antiga.png';
    const newPath = 'profiles/$anaId/nova.png';
    when(
      () => picker.pick(PhotoSource.gallery),
    ).thenAnswer((_) async => PickedPhoto(bytes: tinyPng, type: ImageType.png));
    when(() => profile.uploadPhoto(any(), any())).thenAnswer((_) async => newPath);
    await pump(tester, ownProfile(photoPath: oldPath));

    await tester.tap(find.text(l10nPt.profileChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10nPt.profilePhotoGallery));
    await tester.pumpAndSettle();
    await tester.tap(save());
    await tester.pumpAndSettle();

    verifyInOrder([
      () => profile.uploadPhoto(tinyPng, ImageType.png),
      () => profile.updateProfile(
        name: 'Ana Souza',
        nickname: null,
        photoPath: newPath,
      ),
      () => profile.updatePrivate(phone: null, phoneVisible: false),
      () => profile.deletePhoto(oldPath),
    ]);
  });
}
