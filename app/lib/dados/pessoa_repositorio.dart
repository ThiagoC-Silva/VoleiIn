import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repositorio.dart';

/// Leitura do próprio perfil. A linha nasce pelo gatilho do banco, na confirmação do
/// cadastro com senha ou no primeiro acesso pelo Google.
class PessoaRepositorio {
  PessoaRepositorio(this._cliente);

  final SupabaseClient _cliente;

  Future<String> meuNome() async {
    final linha = await _cliente
        .from('pessoa')
        .select('nome')
        .eq('id', _cliente.auth.currentUser!.id)
        .single();
    return linha['nome'] as String;
  }
}

final pessoaRepositorioProvider =
    Provider<PessoaRepositorio>((ref) => PessoaRepositorio(Supabase.instance.client));

/// Refeito a cada troca de sessão, para não mostrar o nome de quem saiu.
final meuNomeProvider = FutureProvider<String>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(pessoaRepositorioProvider).meuNome();
});
