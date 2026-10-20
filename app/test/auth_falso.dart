import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/dados/auth_repositorio.dart';

export 'package:voleiin/dados/auth_repositorio.dart' show FalhaAuth;

/// Serviço de autenticação de mentira, reaproveitado pelos testes de entrar e de
/// trocar e-mail: só conhece as contas de [existentes] e permite forçar cada falha.
class AuthFalso implements AuthRepositorio {
  AuthFalso({
    this.existentes = const {},
    this.falhaNoCodigo,
    this.emailAtual,
    this.falhaAoPedirTrocaEmail,
  });

  final Set<String> existentes;
  final FalhaAuth? falhaNoCodigo;
  @override
  final String? emailAtual;
  final FalhaAuth? falhaAoPedirTrocaEmail;
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
