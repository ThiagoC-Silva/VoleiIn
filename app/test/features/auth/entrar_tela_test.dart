import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/dados/auth_repositorio.dart';
import 'package:voleiin/features/auth/entrar_tela.dart';

/// Serviço de autenticação de mentira: só conhece as contas de [existentes].
class _AuthFalso implements AuthRepositorio {
  _AuthFalso({this.existentes = const {}, this.falhaNoCodigo});

  final Set<String> existentes;
  final FalhaAuth? falhaNoCodigo;
  final chamadas = <String>[];

  @override
  Future<bool> pedirCodigo(String email) async {
    chamadas.add('pedirCodigo $email');
    return existentes.contains(email);
  }

  @override
  Future<void> criarConta(String email, String nome) async => chamadas.add('criarConta $email $nome');

  @override
  Future<void> confirmarCodigo(String email, String codigo) async {
    chamadas.add('confirmarCodigo $email $codigo');
    if (falhaNoCodigo != null) throw falhaNoCodigo!;
  }

  @override
  Stream<Session?> get sessoes => Stream.value(null);

  @override
  String? get emailAtual => null;

  @override
  Future<void> pedirTrocaEmail(String novo) async {}

  @override
  Future<void> confirmarTrocaEmail(String novo, String codigo) async {}

  @override
  Future<void> sair() async {}
}

Future<void> _abrir(WidgetTester tester, _AuthFalso auth) => tester.pumpWidget(
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
    final auth = _AuthFalso(existentes: {'carla@exemplo.com'});
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
    final auth = _AuthFalso();
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
    final auth = _AuthFalso(
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
    final auth = _AuthFalso(existentes: {'carla@exemplo.com'});
    await _abrir(tester, auth);
    await _digitarEmail(tester, 'carla@exemplo.com');

    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.text('Reenviar código'));
    await tester.pump();

    expect(auth.chamadas, ['pedirCodigo carla@exemplo.com', 'pedirCodigo carla@exemplo.com']);
    expect(find.text('Reenviar código em 60 s'), findsOneWidget);
  });
}
