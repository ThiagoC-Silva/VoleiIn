import 'package:voleiin/dados/auth_repositorio.dart';
import 'package:voleiin/dados/pessoa_repositorio.dart';

/// Perfil de mentira. Registra as chamadas na mesma lista do [AuthFalso] que recebe, para
/// os testes conferirem a ordem entre perfil e autenticação.
class PessoaFalsa implements PessoaRepositorio {
  PessoaFalsa(this.chamadas, {this.falhaAoGravarNome});

  final List<String> chamadas;

  /// Recusa da gravação do nome, só na primeira tentativa.
  FalhaAuth? falhaAoGravarNome;

  @override
  Future<String> meuNome() async => 'Carla';

  @override
  Future<void> gravarNome(String nome) async {
    chamadas.add('gravarNome $nome');
    final falha = falhaAoGravarNome;
    falhaAoGravarNome = null;
    if (falha != null) throw falha;
  }
}
