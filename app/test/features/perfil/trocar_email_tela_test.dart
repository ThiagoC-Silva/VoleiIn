import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/dados/auth_repositorio.dart';
import 'package:voleiin/features/perfil/trocar_email_tela.dart';

import '../../auth_falso.dart';

Future<void> _abrir(WidgetTester tester, AuthFalso auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositorioProvider.overrideWithValue(auth)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('abrir'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrocarEmailTela()),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('abrir')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('e-mail igual ao atual recusa sem chamar o repositório', (tester) async {
    final auth = AuthFalso(emailAtual: 'carla@exemplo.com');
    await _abrir(tester, auth);

    await tester.enterText(find.byKey(const Key('campo-email-novo')), 'carla@exemplo.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Esse já é o e-mail da sua conta.'), findsOneWidget);
    expect(auth.chamadas, isEmpty);
  });

  testWidgets('e-mail de outra conta mostra a mensagem e não avança para o código', (tester) async {
    final auth = AuthFalso(
      emailAtual: 'carla@exemplo.com',
      falhaAoPedirTrocaEmail: const FalhaAuth('Esse e-mail já pertence a outra conta.'),
    );
    await _abrir(tester, auth);

    await tester.enterText(find.byKey(const Key('campo-email-novo')), 'bruno@exemplo.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Esse e-mail já pertence a outra conta.'), findsOneWidget);
    expect(find.byKey(const Key('campo-codigo')), findsNothing);
  });

  testWidgets('código confirmado troca o e-mail, avisa e fecha a tela', (tester) async {
    final auth = AuthFalso(emailAtual: 'carla@exemplo.com');
    await _abrir(tester, auth);

    await tester.enterText(find.byKey(const Key('campo-email-novo')), 'carla2@exemplo.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('campo-codigo')), '123456');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(auth.chamadas.last, 'confirmarTrocaEmail carla2@exemplo.com 123456');
    expect(find.text('E-mail trocado. Os outros aparelhos foram desconectados.'), findsOneWidget);
    expect(find.byKey(const Key('abrir')), findsOneWidget);
  });

  testWidgets('reenvio depois de 60 s chama pedirTrocaEmail de novo', (tester) async {
    final auth = AuthFalso(emailAtual: 'carla@exemplo.com');
    await _abrir(tester, auth);

    await tester.enterText(find.byKey(const Key('campo-email-novo')), 'carla2@exemplo.com');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, [
      'pedirTrocaEmail carla2@exemplo.com',
      'pedirTrocaEmail carla2@exemplo.com',
    ]);
  });
}
