import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/auth_repositorio.dart';
import '../features/auth/entrar_tela.dart';
import '../features/feed/inicio_tela.dart';

/// Escolhe a tela pela sessão: sem sessão, entrar; com sessão, o início.
/// Sair da conta, ou perder a sessão na troca de e-mail feita em outro aparelho,
/// volta para entrar sem navegação explícita.
class Raiz extends ConsumerWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(sessaoProvider).when(
          data: (sessao) => sessao == null ? const EntrarTela() : const InicioTela(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const EntrarTela(),
        );
  }
}
