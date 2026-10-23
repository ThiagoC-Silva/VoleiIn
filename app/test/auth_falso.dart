import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/dados/auth_repositorio.dart';

export 'package:voleiin/dados/auth_repositorio.dart' show FalhaAuth;

/// Serviço de autenticação de mentira, reaproveitado pelos testes das telas de acesso e de
/// trocar e-mail: registra cada chamada em [chamadas] e permite forçar cada falha.
class AuthFalso implements AuthRepositorio {
  AuthFalso({
    this.emailAtual,
    this.naoConfirmados = const {},
    this.falhaAoEntrar,
    this.falhaAoCriarConta,
    this.falhaNoCodigo,
    this.falhaAoPedirTrocaEmail,
    this.falhaAoSalvarSenha,
  });

  @override
  final String? emailAtual;

  /// Cadastros pendentes: [entrar] devolve false, como o serviço com email_not_confirmed.
  final Set<String> naoConfirmados;
  final FalhaAuth? falhaAoEntrar;
  final FalhaAuth? falhaAoCriarConta;

  /// Recusa do código, na confirmação do cadastro e na redefinição de senha.
  final FalhaAuth? falhaNoCodigo;
  final FalhaAuth? falhaAoPedirTrocaEmail;

  /// Recusa da senha nova depois do código conferido, só na primeira tentativa.
  FalhaAuth? falhaAoSalvarSenha;
  final chamadas = <String>[];

  @override
  Stream<Session?> get sessoes => Stream.value(null);

  @override
  Future<bool> entrar(String email, String senha) async {
    chamadas.add('entrar $email $senha');
    if (falhaAoEntrar != null) throw falhaAoEntrar!;
    return !naoConfirmados.contains(email);
  }

  @override
  Future<void> criarConta(String nome, String email, String senha) async {
    chamadas.add('criarConta $nome $email $senha');
    if (falhaAoCriarConta != null) throw falhaAoCriarConta!;
  }

  @override
  Future<void> confirmarCadastro(String email, String codigo) async {
    chamadas.add('confirmarCadastro $email $codigo');
    if (falhaNoCodigo != null) throw falhaNoCodigo!;
  }

  @override
  Future<void> reenviarConfirmacao(String email) async => chamadas.add('reenviarConfirmacao $email');

  @override
  Future<void> entrarComGoogle() async => chamadas.add('entrarComGoogle');

  @override
  Future<void> pedirRedefinicao(String email) async => chamadas.add('pedirRedefinicao $email');

  @override
  Future<void> conferirCodigoRedefinicao(String email, String codigo) async {
    chamadas.add('conferirCodigoRedefinicao $email $codigo');
    if (falhaNoCodigo != null) throw falhaNoCodigo!;
  }

  @override
  Future<void> salvarSenhaNova(String nova) async {
    chamadas.add('salvarSenhaNova $nova');
    final falha = falhaAoSalvarSenha;
    falhaAoSalvarSenha = null;
    if (falha != null) throw falha;
  }

  @override
  Future<void> pedirTrocaEmail(String novo) async {
    chamadas.add('pedirTrocaEmail $novo');
    if (falhaAoPedirTrocaEmail != null) throw falhaAoPedirTrocaEmail!;
  }

  @override
  Future<void> confirmarTrocaEmail(String novo, String codigo) async =>
      chamadas.add('confirmarTrocaEmail $novo $codigo');

  @override
  Future<void> sair() async => chamadas.add('sair');
}
