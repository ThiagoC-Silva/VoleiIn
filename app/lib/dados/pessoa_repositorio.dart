import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repositorio.dart';

/// O próprio perfil. A linha nasce pelo gatilho do banco, na confirmação do cadastro com
/// senha ou no primeiro acesso pelo Google.
class PessoaRepositorio {
  PessoaRepositorio(this._cliente);

  final SupabaseClient _cliente;

  String get _meuId => _cliente.auth.currentUser!.id;

  Future<String> meuNome() async {
    final linha = await _cliente.from('pessoa').select('nome').eq('id', _meuId).single();
    return linha['nome'] as String;
  }

  /// Grava o nome de exibição, uma das escritas diretas permitidas ao app (passo 2). A
  /// falha chega como [FalhaAuth] porque, por ora, só a confirmação do cadastro grava aqui.
  Future<void> gravarNome(String nome) async {
    try {
      await _cliente.from('pessoa').update({'nome': nome}).eq('id', _meuId);
    } on PostgrestException {
      throw const FalhaAuth(mensagemGenerica);
    } on Exception {
      // Sem resposta do servidor: o cliente HTTP falha antes de haver um PostgrestException.
      throw const FalhaAuth(mensagemSemConexao);
    }
  }
}

final pessoaRepositorioProvider =
    Provider<PessoaRepositorio>((ref) => PessoaRepositorio(Supabase.instance.client));

/// Refeito a cada troca de sessão, para não mostrar o nome de quem saiu.
final meuNomeProvider = FutureProvider<String>((ref) {
  ref.watch(sessaoProvider);
  return ref.watch(pessoaRepositorioProvider).meuNome();
});
