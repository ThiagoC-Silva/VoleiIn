import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/dados/auth_repositorio.dart';
import 'package:voleiin/features/auth/entrar_tela.dart';

import '../../auth_falso.dart';

Future<void> _abrir(WidgetTester tester, AuthFalso auth) => tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositorioProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: EntrarTela()),
      ),
    );

Future<void> _digitarEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('campo-email')), email);
  await tester.tap(find.text('Continuar'));
  await tester.pump();
}

void main() {
  testWidgets('conta existente vai direto ao código, sem pedir nome', (tester) async {
    final auth = AuthFalso(existentes: {'carla@exemplo.com'});
    await _abrir(tester, auth);

    await _digitarEmail(tester, '  Carla@Exemplo.com ');

    expect(find.byKey(const Key('campo-nome')), findsNothing);
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
    expect(auth.chamadas, ['pedirCodigo carla@exemplo.com']);

    await tester.enterText(find.byKey(const Key('campo-codigo')), '123456');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(auth.chamadas.last, 'confirmarCodigo carla@exemplo.com 123456');
  });

  testWidgets('e-mail sem conta pede o nome e cria a conta com ele', (tester) async {
    final auth = AuthFalso();
    await _abrir(tester, auth);

    await _digitarEmail(tester, 'bruno@exemplo.com');
    expect(find.byKey(const Key('campo-nome')), findsOneWidget);

    await tester.tap(find.text('Criar conta'));
    await tester.pump();
    expect(find.text('Informe como a turma vai te ver.'), findsOneWidget);
    expect(auth.chamadas, ['pedirCodigo bruno@exemplo.com']);

    await tester.enterText(find.byKey(const Key('campo-nome')), ' Bruno ');
    await tester.tap(find.text('Criar conta'));
    await tester.pump();

    expect(auth.chamadas.last, 'criarConta bruno@exemplo.com Bruno');
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
  });

  testWidgets('código recusado mostra a mensagem e mantém a etapa', (tester) async {
    final auth = AuthFalso(
      existentes: {'carla@exemplo.com'},
      falhaNoCodigo: const FalhaAuth('Código inválido ou vencido. Confira ou peça outro.'),
    );
    await _abrir(tester, auth);

    await _digitarEmail(tester, 'carla@exemplo.com');
    await tester.enterText(find.byKey(const Key('campo-codigo')), '000000');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pump();

    expect(find.text('Código inválido ou vencido. Confira ou peça outro.'), findsOneWidget);
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
  });

  testWidgets('reenvio só libera depois do intervalo mínimo', (tester) async {
    final auth = AuthFalso(existentes: {'carla@exemplo.com'});
    await _abrir(tester, auth);
    await _digitarEmail(tester, 'carla@exemplo.com');

    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, ['pedirCodigo carla@exemplo.com', 'pedirCodigo carla@exemplo.com']);
    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
  });

  testWidgets('voltar da etapa de código retorna para a etapa de e-mail', (tester) async {
    final auth = AuthFalso(existentes: {'carla@exemplo.com'});
    await _abrir(tester, auth);
    await _digitarEmail(tester, 'carla@exemplo.com');
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar e-mail'));
    await tester.pump();

    expect(find.byKey(const Key('campo-email')), findsOneWidget);
    expect(find.byKey(const Key('campo-codigo')), findsNothing);
  });

  testWidgets('reenvio de conta nova cria a conta de novo, não pede só o código', (tester) async {
    final auth = AuthFalso();
    await _abrir(tester, auth);

    await _digitarEmail(tester, 'bruno@exemplo.com');
    await tester.enterText(find.byKey(const Key('campo-nome')), 'Bruno');
    await tester.tap(find.text('Criar conta'));
    await tester.pump();
    expect(auth.chamadas, ['pedirCodigo bruno@exemplo.com', 'criarConta bruno@exemplo.com Bruno']);

    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, [
      'pedirCodigo bruno@exemplo.com',
      'criarConta bruno@exemplo.com Bruno',
      'criarConta bruno@exemplo.com Bruno',
    ]);
  });
}
