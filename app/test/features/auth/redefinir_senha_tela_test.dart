import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/redefinir_senha_tela.dart';

import '../../auth_falso.dart';
import '../../montar.dart';

final _salvar = find.widgetWithText(FilledButton, 'Salvar nova senha');

Future<void> _pedirCodigo(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('campo-email')), email);
  await tester.tap(find.text('Enviar código'));
  await tester.pump();
}

Future<void> _tocarSalvar(WidgetTester tester) async {
  await tester.ensureVisible(_salvar);
  await tester.pump();
  await tester.tap(_salvar);
}

Future<void> _preencher(WidgetTester tester, String codigo, String nova) async {
  await tester.enterText(find.byKey(const Key('campo-codigo')), codigo);
  await tester.enterText(find.byKey(const Key('campo-senha-nova')), nova);
  await tester.pump();
}

void main() {
  testWidgets('o pedido manda o e-mail aparado e segue ao código sem afirmar que há conta', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);

    await _pedirCodigo(tester, ' Carla@Exemplo.com ');

    expect(auth.chamadas, ['pedirRedefinicao carla@exemplo.com']);
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
    expect(find.textContaining('Se houver conta com carla@exemplo.com', findRichText: true), findsOneWidget);
  });

  testWidgets('senha nova curta não deixa salvar', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);
    await _pedirCodigo(tester, 'carla@exemplo.com');

    await _preencher(tester, '123456', 'curta');
    expect(tester.widget<FilledButton>(_salvar).onPressed, isNull);

    await _tocarSalvar(tester);
    await tester.pump();
    expect(auth.chamadas, ['pedirRedefinicao carla@exemplo.com']);
  });

  testWidgets('código e senha nova redefinem a senha, avisam e desfazem a pilha', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);
    await _pedirCodigo(tester, 'carla@exemplo.com');

    await _preencher(tester, '123456', 'novaSenha1');
    await _tocarSalvar(tester);
    await tester.pumpAndSettle();

    expect(auth.chamadas.skip(1), [
      'conferirCodigoRedefinicao carla@exemplo.com 123456',
      'salvarSenhaNova novaSenha1',
    ]);
    expect(find.text('Senha trocada. Os outros aparelhos foram desconectados.'), findsOneWidget);
    expect(find.byKey(const Key('abrir')), findsOneWidget);
  });

  // Visto no celular (T07.8): a conferência gasta o código, e conferi-lo de novo depois
  // de uma senha recusada dava "código inválido".
  testWidgets('senha recusada depois do código conferido: a nova tentativa não confere o código de novo',
      (tester) async {
    const igual = 'A senha nova precisa ser diferente da atual.';
    final auth = AuthFalso(falhaAoSalvarSenha: const FalhaAuth(igual));
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);
    await _pedirCodigo(tester, 'carla@exemplo.com');

    await _preencher(tester, '123456', 'senhaAtual1');
    await _tocarSalvar(tester);
    await tester.pumpAndSettle();
    expect(find.text(igual), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-senha-nova')), 'outraSenha2');
    await _tocarSalvar(tester);
    await tester.pumpAndSettle();

    expect(auth.chamadas.skip(1), [
      'conferirCodigoRedefinicao carla@exemplo.com 123456',
      'salvarSenhaNova senhaAtual1',
      'salvarSenhaNova outraSenha2',
    ]);
    expect(find.byKey(const Key('abrir')), findsOneWidget);
  });

  testWidgets('código recusado mostra a mensagem e mantém a tela', (tester) async {
    const recusado = 'Código inválido ou vencido. Confira ou peça outro.';
    final auth = AuthFalso(falhaNoCodigo: const FalhaAuth(recusado));
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);
    await _pedirCodigo(tester, 'carla@exemplo.com');

    await _preencher(tester, '000000', 'novaSenha1');
    await _tocarSalvar(tester);
    await tester.pumpAndSettle();

    expect(find.text(recusado), findsOneWidget);
    expect(find.text('Redefinir senha'), findsOneWidget);
  });

  testWidgets('reenvio depois de 60 s pede outro código', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const RedefinirSenhaTela(), empilhada: true);
    await _pedirCodigo(tester, 'carla@exemplo.com');

    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, ['pedirRedefinicao carla@exemplo.com', 'pedirRedefinicao carla@exemplo.com']);
  });

  testWidgets('aberta pela sessão, o e-mail vem travado no da conta', (tester) async {
    final auth = AuthFalso();
    await montar(
      tester,
      auth,
      const RedefinirSenhaTela(email: 'carla@exemplo.com', daSessao: true),
      empilhada: true,
    );

    final campo = tester.widget<TextField>(find.byKey(const Key('campo-email')));
    expect(campo.readOnly, isTrue);
    expect(campo.controller!.text, 'carla@exemplo.com');

    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    expect(auth.chamadas, ['pedirRedefinicao carla@exemplo.com']);
    expect(
      find.textContaining('Digite o código enviado para carla@exemplo.com', findRichText: true),
      findsOneWidget,
    );
  });
}
