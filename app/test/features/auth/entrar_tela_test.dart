import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/entrar_tela.dart';

import '../../auth_falso.dart';
import '../../montar.dart';

Future<void> _entrar(WidgetTester tester, String email, String senha) async {
  await tester.enterText(find.byKey(const Key('campo-email')), email);
  await tester.enterText(find.byKey(const Key('campo-senha')), senha);
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('senha certa entra com o e-mail aparado e minúsculo', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const EntrarTela());

    await _entrar(tester, '  Carla@Exemplo.com ', 'segredo123');

    expect(auth.chamadas, ['entrar carla@exemplo.com segredo123']);
    expect(find.text('Confirmar e-mail'), findsNothing);
  });

  testWidgets('senha recusada mostra a mensagem e fica na tela', (tester) async {
    final auth = AuthFalso(falhaAoEntrar: const FalhaAuth('E-mail ou senha incorretos.'));
    await montar(tester, auth, const EntrarTela());

    await _entrar(tester, 'carla@exemplo.com', 'errada123');

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.byKey(const Key('campo-senha')), findsOneWidget);
  });

  testWidgets('senha curta e e-mail sem arroba são recusados sem chamar o serviço', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const EntrarTela());

    await _entrar(tester, 'carla', 'curta');

    expect(find.text('Confira o e-mail digitado.'), findsOneWidget);
    expect(find.text('A senha precisa de pelo menos 8 caracteres.'), findsOneWidget);
    expect(auth.chamadas, isEmpty);
  });

  testWidgets('conta não confirmada segue para a confirmação do e-mail', (tester) async {
    final auth = AuthFalso(naoConfirmados: {'carla@exemplo.com'});
    await montar(tester, auth, const EntrarTela());

    await _entrar(tester, 'carla@exemplo.com', 'segredo123');

    expect(find.text('Confirmar e-mail'), findsOneWidget);
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
  });

  testWidgets('entrar com Google chama o serviço', (tester) async {
    final auth = AuthFalso();
    await montar(tester, auth, const EntrarTela());

    await tester.ensureVisible(find.text('Entrar com Google'));
    await tester.pump();
    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(auth.chamadas, ['entrarComGoogle']);
  });

  testWidgets('criar conta abre o cadastro com o e-mail já digitado', (tester) async {
    await montar(tester, AuthFalso(), const EntrarTela());

    await tester.enterText(find.byKey(const Key('campo-email')), ' Bruno@Exemplo.com');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.pump();
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Como a turma vai te ver?'), findsOneWidget);
    expect(textoDoCampo(tester, 'campo-email'), 'bruno@exemplo.com');
  });
}
