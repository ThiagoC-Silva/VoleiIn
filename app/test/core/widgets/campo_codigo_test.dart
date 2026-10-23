import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/tema.dart';
import 'package:voleiin/core/widgets/campo_codigo.dart';

final _campo = find.byKey(const Key('campo-codigo'));

Future<void> _montar(WidgetTester tester, TextEditingController controller, {required bool habilitado}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: temaVoleiIn,
        home: Scaffold(body: CampoCodigo(controller: controller, habilitado: habilitado)),
      ),
    );

bool _temFoco(WidgetTester tester) =>
    tester.widget<EditableText>(find.descendant(of: _campo, matching: find.byType(EditableText))).focusNode.hasFocus;

void main() {
  // Visto no celular (T07.8): depois do reenvio ou de um código recusado, o teclado
  // fechava e o código digitado em seguida se perdia.
  testWidgets('travado durante a chamada, devolve o foco ao ser destravado', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _montar(tester, controller, habilitado: true);
    await tester.pump();
    expect(_temFoco(tester), isTrue);

    await _montar(tester, controller, habilitado: false);
    await tester.pump();
    expect(_temFoco(tester), isFalse);

    await _montar(tester, controller, habilitado: true);
    await tester.pump();
    expect(_temFoco(tester), isTrue);
  });

  testWidgets('sem foco ao ser travado, continua sem foco ao ser destravado', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _montar(tester, controller, habilitado: true);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await _montar(tester, controller, habilitado: false);
    await tester.pump();
    await _montar(tester, controller, habilitado: true);
    await tester.pump();
    expect(_temFoco(tester), isFalse);
  });
}
