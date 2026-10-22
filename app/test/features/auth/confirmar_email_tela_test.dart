import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/confirmar_email_tela.dart';

import '../../auth_falso.dart';
import '../../montar.dart';

const _tela = ConfirmarEmailTela(email: 'carla@exemplo.com');
final _botao = find.widgetWithText(FilledButton, 'Confirmar');

void main() {
  testWidgets('seis dígitos liberam o Confirmar, que conclui o cadastro e desfaz a pilha', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, _tela, empilhada: true);
    expect(tester.widget<FilledButton>(_botao).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('campo-codigo')), '123456');
    await tester.pump();
    await tester.tap(_botao);
    await tester.pumpAndSettle();

    expect(auth.chamadas, ['confirmarCadastro carla@exemplo.com 123456']);
    expect(find.byKey(const Key('abrir')), findsOneWidget);
  });

  testWidgets('código recusado mostra a mensagem e mantém a tela', (tester) async {
    const recusado = 'Código inválido ou vencido. Confira ou peça outro.';
    final auth = AuthFalso(falhaNoCodigo: const FalhaAuth(recusado));
    await montar(tester, auth, _tela, empilhada: true);

    await tester.enterText(find.byKey(const Key('campo-codigo')), '000000');
    await tester.pump();
    await tester.tap(_botao);
    await tester.pumpAndSettle();

    expect(find.text(recusado), findsOneWidget);
    expect(find.text('Confirmar e-mail'), findsOneWidget);
  });

  testWidgets('reenvio só libera depois de 60 s e pede outro código', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, _tela, empilhada: true);

    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, ['reenviarConfirmacao carla@exemplo.com']);
    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
  });

  testWidgets('voltar retorna à tela anterior', (tester) async {
    await montar(tester, AuthFalso(), _tela, empilhada: true);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('abrir')), findsOneWidget);
    expect(find.text('Confirmar e-mail'), findsNothing);
  });
}
