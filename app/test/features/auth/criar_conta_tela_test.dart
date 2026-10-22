import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/criar_conta_tela.dart';

import '../../auth_falso.dart';
import '../../montar.dart';

final _botao = find.widgetWithText(FilledButton, 'Criar conta');

Future<void> _preencher(WidgetTester tester, {String nome = '', String email = '', String senha = ''}) async {
  await tester.enterText(find.byKey(const Key('campo-nome')), nome);
  await tester.enterText(find.byKey(const Key('campo-email')), email);
  await tester.enterText(find.byKey(const Key('campo-senha')), senha);
  await tester.pump();
}

bool _habilitado(WidgetTester tester) => tester.widget<FilledButton>(_botao).onPressed != null;

void main() {
  testWidgets('sem nome ou com senha curta o botão fica desabilitado', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const CriarContaTela());

    await _preencher(tester, email: 'bruno@exemplo.com', senha: 'segredo123');
    expect(_habilitado(tester), isFalse);

    await _preencher(tester, nome: 'Bruno', email: 'bruno@exemplo.com', senha: 'curta');
    expect(_habilitado(tester), isFalse);

    await tester.tap(_botao);
    await tester.pump();
    expect(auth.chamadas, isEmpty);
  });

  testWidgets('cadastro manda nome e e-mail aparados e segue para o código', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const CriarContaTela());

    await _preencher(tester, nome: ' Bruno ', email: ' Bruno@Exemplo.com ', senha: 'segredo123');
    await tester.tap(_botao);
    await tester.pumpAndSettle();

    expect(auth.chamadas, ['criarConta Bruno bruno@exemplo.com segredo123']);
    expect(find.text('Confirmar e-mail'), findsOneWidget);
  });

  testWidgets('e-mail que já tem conta mostra a mensagem e não avança', (tester) async {
    const jaTemConta = 'Esse e-mail já tem conta. Entre com a senha ou pelo Google.';
    final auth = AuthFalso(falhaAoCriarConta: const FalhaAuth(jaTemConta));
    await montar(tester, auth, const CriarContaTela());

    await _preencher(tester, nome: 'Bruno', email: 'bruno@exemplo.com', senha: 'segredo123');
    await tester.tap(_botao);
    await tester.pumpAndSettle();

    expect(find.text(jaTemConta), findsOneWidget);
    expect(find.text('Confirmar e-mail'), findsNothing);
  });
}
