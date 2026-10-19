import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Falha do serviço de autenticação, já com a mensagem para a tela.
class FalhaAuth implements Exception {
  const FalhaAuth(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso por código de seis dígitos e troca de e-mail (RN21, RNF06, RNF07).
/// Código, validade e limite de envios são do Supabase Auth; aqui só se pede e se confirma.
/// Detalhes em docs/stack.md, seção Autenticação.
class AuthRepositorio {
  AuthRepositorio(this._auth);

  final GoTrueClient _auth;

  /// Sessão atual e cada mudança dela; a primeira emissão é a sessão guardada no aparelho.
  Stream<Session?> get sessoes => _auth.onAuthStateChange.map((estado) => estado.session);

  String? get emailAtual => _auth.currentUser?.email;

  /// Pede o código para uma conta que já existe. Devolve false, sem enviar nada,
  /// quando o e-mail não tem conta: a tela pede então o nome e chama [criarConta].
  Future<bool> pedirCodigo(String email) async {
    try {
      await _auth.signInWithOtp(email: email, shouldCreateUser: false);
      return true;
    } on AuthException catch (e) {
      if (e.code == 'otp_disabled') return false;
      throw _traduzir(e);
    }
  }

  /// Cria a conta e envia o código. O nome vai nos metadados, de onde o gatilho
  /// privado.criar_pessoa monta o perfil; sem nome, o banco recusa o cadastro.
  Future<void> criarConta(String email, String nome) =>
      _executar(() => _auth.signInWithOtp(email: email, shouldCreateUser: true, data: {'nome': nome}));

  Future<void> confirmarCodigo(String email, String codigo) =>
      _executar(() => _auth.verifyOTP(type: OtpType.email, email: email, token: codigo));

  /// Envia o código ao endereço novo; o antigo só recebe o aviso quando a troca se concluir.
  Future<void> pedirTrocaEmail(String novo) =>
      _executar(() => _auth.updateUser(UserAttributes(email: novo)));

  /// Conclui a troca e derruba as sessões dos outros aparelhos; a deste continua (RNF07).
  /// Os aparelhos de push são apagados pelo gatilho do banco, não por aqui.
  Future<void> confirmarTrocaEmail(String novo, String codigo) => _executar(() async {
        await _auth.verifyOTP(type: OtpType.emailChange, email: novo, token: codigo);
        await _auth.signOut(scope: SignOutScope.others);
      });

  Future<void> sair() => _executar(() => _auth.signOut());

  Future<void> _executar(Future<void> Function() acao) async {
    try {
      await acao();
    } on AuthException catch (e) {
      throw _traduzir(e);
    }
  }

  FalhaAuth _traduzir(AuthException e) {
    if (e is AuthRetryableFetchException) {
      return const FalhaAuth('Sem conexão. Confira a internet e tente de novo.');
    }
    return FalhaAuth(switch (e.code) {
      'over_email_send_rate_limit' => 'Aguarde um minuto antes de pedir outro código.',
      'over_request_rate_limit' => 'Muitas tentativas seguidas. Aguarde alguns minutos.',
      'otp_expired' => 'Código inválido ou vencido. Confira ou peça outro.',
      'email_exists' => 'Esse e-mail já pertence a outra conta.',
      'email_address_invalid' || 'validation_failed' => 'Confira o e-mail digitado.',
      _ => 'Não foi possível concluir agora. Tente de novo.',
    });
  }
}

final authRepositorioProvider =
    Provider<AuthRepositorio>((ref) => AuthRepositorio(Supabase.instance.client.auth));

final sessaoProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositorioProvider).sessoes);
