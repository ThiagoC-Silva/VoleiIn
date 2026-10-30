import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/core/rotas.dart';
import 'package:voleiin/core/tema.dart';
import 'package:voleiin/dados/auth_repositorio.dart';
import 'package:voleiin/dados/pessoa_repositorio.dart';
import 'package:voleiin/features/auth/entrar_tela.dart';
import 'package:voleiin/features/feed/inicio_tela.dart';

import '../auth_falso.dart';
import '../pessoa_falsa.dart';

Session _sessao() => Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-29T00:00:00Z',
      ),
    );

Future<StreamController<Session?>> _montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final sessoes = StreamController<Session?>();
  addTearDown(sessoes.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessaoProvider.overrideWith((ref) => sessoes.stream),
        authRepositorioProvider.overrideWithValue(AuthFalso(emailAtual: 'carla@exemplo.com')),
        pessoaRepositorioProvider.overrideWithValue(PessoaFalsa([])),
      ],
      child: MaterialApp(theme: temaVoleiIn, home: const Raiz()),
    ),
  );
  return sessoes;
}

void main() {
  testWidgets('a Raiz espera a sessão guardada, depois escolhe a tela por ela', (tester) async {
    final sessoes = await _montar(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    sessoes.add(null);
    await tester.pump();
    expect(find.byType(EntrarTela), findsOneWidget);
    expect(find.byType(InicioTela), findsNothing);

    sessoes.add(_sessao());
    await tester.pump();
    await tester.pump();
    expect(find.byType(InicioTela), findsOneWidget);
    expect(find.text('Olá, Carla'), findsOneWidget);
  });

  testWidgets('perder a sessão volta para entrar, sem navegação explícita', (tester) async {
    final sessoes = await _montar(tester);
    sessoes.add(_sessao());
    await tester.pump();
    await tester.pump();
    expect(find.byType(InicioTela), findsOneWidget);

    sessoes.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.byType(EntrarTela), findsOneWidget);
    expect(find.byType(InicioTela), findsNothing);
  });

  testWidgets('falha ao ler a sessão mostra a entrada', (tester) async {
    final sessoes = await _montar(tester);
    sessoes.addError(StateError('sem sessão'));
    await tester.pump();
    expect(find.byType(EntrarTela), findsOneWidget);
  });
}
