import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S13 de docs/testes-referencia.md, seção 10.4 (docs/ui/telas.md, 5.9).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
    h.ownProfile(pixKeyType: PixKeyType.cpf, pixKey: '52998224725');
    when(
      () => h.profiles.updatePixKey(
        type: any(named: 'type'),
        key: any(named: 'key'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> open(WidgetTester tester) async {
    await h.pumpApp(tester, location: '/profile');
    await h.push(tester, '/profile/pix');
  }

  final keyField = find.byType(TextFormField);

  String typedKey(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(of: keyField, matching: find.byType(EditableText)),
      )
      .controller
      .text;

  Future<void> chooseType(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('pixTypeSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(buttonWithText<FilledButton>(l10nPt.commonSave));
    await tester.pumpAndSettle();
  }

  void verifyNoWrite() => verifyNever(
    () => h.profiles.updatePixKey(
      type: any(named: 'type'),
      key: any(named: 'key'),
    ),
  );

  testWidgets('a tela abre com a chave atual, formatada', (tester) async {
    await open(tester);

    expect(typedKey(tester), '529.982.247-25');
    expect(find.text(l10nPt.pixRemove), findsOneWidget);
  });

  testWidgets('S13: CPF com dígito errado mostra erro e não chama o servidor', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(keyField, '52998224724');
    await save(tester);

    expect(find.text(l10nPt.pixInvalidCpf), findsOneWidget);
    verifyNoWrite();
  });

  testWidgets('S13: trocar o tipo de CPF para E-mail limpa o campo', (
    tester,
  ) async {
    await open(tester);

    await chooseType(tester, l10nPt.pixTypeEmail);

    expect(typedKey(tester), isEmpty);
  });

  testWidgets(
    'S13: remoção recusada (PIX_KEY_IN_USE) vira SnackBar, e a chave continua na tela',
    (tester) async {
      when(() => h.profiles.updatePixKey(type: null, key: null))
          .thenThrow(const AppException(ErrorCode.pixKeyInUse));
      await open(tester);

      await tester.tap(find.text(l10nPt.pixRemove));
      await tester.pumpAndSettle();

      // Confirmação destrutiva (design-system.md, 7.15).
      expect(find.text(l10nPt.pixRemoveTitle), findsOneWidget);
      expect(find.text(l10nPt.pixRemoveBody), findsOneWidget);
      expect(find.text(l10nPt.commonBack), findsOneWidget);

      await tester.tap(buttonWithText<FilledButton>(l10nPt.pixRemoveConfirm));
      await tester.pumpAndSettle();

      verify(() => h.profiles.updatePixKey(type: null, key: null)).called(1);
      expect(find.text(l10nPt.errorPixKeyInUse), findsOneWidget);
      expect(typedKey(tester), '529.982.247-25');
      expect(h.location, '/profile/pix');
    },
  );

  testWidgets('Voltar na confirmação não remove a chave', (tester) async {
    await open(tester);

    await tester.tap(find.text(l10nPt.pixRemove));
    await tester.pumpAndSettle();
    await tester.tap(buttonWithText<OutlinedButton>(l10nPt.commonBack));
    await tester.pumpAndSettle();

    verifyNoWrite();
    expect(find.text(l10nPt.pixRemoveTitle), findsNothing);
  });

  testWidgets('remoção aceita grava os dois campos nulos e volta ao perfil', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text(l10nPt.pixRemove));
    await tester.pumpAndSettle();
    await tester.tap(buttonWithText<FilledButton>(l10nPt.pixRemoveConfirm));
    await tester.pumpAndSettle();

    verify(() => h.profiles.updatePixKey(type: null, key: null)).called(1);
    expect(h.location, '/profile');
  });

  testWidgets('salva o e-mail em minúsculas e volta ao perfil', (tester) async {
    await open(tester);

    await chooseType(tester, l10nPt.pixTypeEmail);
    await tester.enterText(keyField, ' Ana@Exemplo.com ');
    await save(tester);

    verify(
      () => h.profiles.updatePixKey(
        type: PixKeyType.email,
        key: 'ana@exemplo.com',
      ),
    ).called(1);
    expect(find.text(l10nPt.pixSaved), findsOneWidget);
    expect(h.location, '/profile');
  });

  testWidgets('salva o CPF só com os dígitos', (tester) async {
    await open(tester);

    await tester.enterText(keyField, '52998224725');
    await save(tester);

    verify(
      () => h.profiles.updatePixKey(type: PixKeyType.cpf, key: '52998224725'),
    ).called(1);
  });

  testWidgets('salva o telefone em E.164', (tester) async {
    await open(tester);

    await chooseType(tester, l10nPt.pixTypePhone);
    await tester.enterText(keyField, '86999991234');
    await save(tester);

    verify(
      () => h.profiles.updatePixKey(
        type: PixKeyType.phone,
        key: '+5586999991234',
      ),
    ).called(1);
  });

  testWidgets('salva o CNPJ alfanumérico sem pontuação e em maiúsculas', (
    tester,
  ) async {
    await open(tester);

    await chooseType(tester, l10nPt.pixTypeCnpj);
    await tester.enterText(keyField, '12abc34501de35');
    await save(tester);

    verify(
      () =>
          h.profiles.updatePixKey(type: PixKeyType.cnpj, key: '12ABC34501DE35'),
    ).called(1);
  });

  for (final (label, typed, error) in [
    (l10nPt.pixTypeCnpj, '11222333000180', l10nPt.pixInvalidCnpj),
    (l10nPt.pixTypeEmail, 'ana-sem-arroba', l10nPt.pixInvalidEmail),
    (l10nPt.pixTypePhone, '869999123', l10nPt.pixInvalidPhone),
    (l10nPt.pixTypeRandom, 'nao-e-uuid', l10nPt.pixInvalidRandom),
  ]) {
    testWidgets('chave inválida do tipo $label mostra "$error"', (
      tester,
    ) async {
      await open(tester);

      await chooseType(tester, label);
      await tester.enterText(keyField, typed);
      await save(tester);

      expect(find.text(error), findsOneWidget);
      verifyNoWrite();
    });
  }

  testWidgets('sem chave cadastrada, não há Remover chave', (tester) async {
    h.ownProfile();
    await open(tester);

    expect(find.text(l10nPt.pixRemove), findsNothing);
    expect(typedKey(tester), isEmpty);
  });
}
