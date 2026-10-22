import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/auth_repositorio.dart';

/// Estado comum das telas que chamam o serviço de autenticação: [ocupado] durante a
/// chamada, e a [FalhaAuth] dela em [erro], já com a mensagem para a tela.
mixin ExecucaoAuth<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  var ocupado = false;
  String? erro;

  /// Devolve se a ação concluiu sem falha.
  Future<bool> executar(Future<void> Function(AuthRepositorio repositorio) acao) async {
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      await acao(ref.read(authRepositorioProvider));
      return true;
    } on FalhaAuth catch (falha) {
      if (mounted) setState(() => erro = falha.mensagem);
      return false;
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
}
