import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/auth_repositorio.dart';
import '../../dados/pessoa_repositorio.dart';
import '../auth/redefinir_senha_tela.dart';
import '../perfil/trocar_email_tela.dart';

/// Tela inicial provisória do passo 3; o feed do passo 5 toma o lugar dela.
/// Sair aqui ainda não apaga o aparelho de push: isso chega com o passo 7.
class InicioTela extends ConsumerWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nome = ref.watch(meuNomeProvider);
    final email = ref.watch(authRepositorioProvider).emailAtual ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('VoleiIn')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              nome.when(
                data: (nome) => 'Olá, $nome',
                loading: () => 'Carregando…',
                error: (_, _) => 'Não foi possível carregar o perfil.',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(email),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TrocarEmailTela()),
              ),
              child: const Text('Trocar e-mail'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => RedefinirSenhaTela(email: email, daSessao: true)),
              ),
              child: const Text('Trocar senha'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.read(authRepositorioProvider).sair(),
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
