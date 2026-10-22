import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/tema.dart';
import 'package:voleiin/dados/auth_repositorio.dart';

import 'auth_falso.dart';

/// Monta [tela] num aparelho do tamanho de um celular, com o tema do app e o [auth] falso.
/// Com [empilhada], ela abre por cima de uma tela com o botão 'abrir', para que voltar e
/// desfazer a pilha tenham para onde ir.
Future<void> montar(WidgetTester tester, AuthFalso auth, Widget tela, {bool empilhada = false}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositorioProvider.overrideWithValue(auth)],
      child: MaterialApp(
        theme: temaVoleiIn,
        home: empilhada
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const Key('abrir'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela)),
                      child: const Text('abrir'),
                    ),
                  ),
                ),
              )
            : tela,
      ),
    ),
  );
  if (empilhada) {
    await tester.tap(find.byKey(const Key('abrir')));
    await tester.pumpAndSettle();
  }
}

/// Texto do campo de [chave] na tela visível.
String textoDoCampo(WidgetTester tester, String chave) =>
    tester.widget<TextField>(find.byKey(Key(chave))).controller!.text;
