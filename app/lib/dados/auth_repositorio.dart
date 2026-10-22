import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mínimo do servidor (minimum_password_length). A tela confere antes só para não gastar
/// uma chamada que seria recusada.
const tamanhoMinimoSenha = 8;

const _jaTemConta = 'Esse e-mail já tem conta. Entre com a senha ou pelo Google.';
const _falhaGoogle = 'Não foi possível entrar com o Google. Entre com e-mail e senha.';

/// Falha do serviço de autenticação, já com a mensagem para a tela.
class FalhaAuth implements Exception {
  const FalhaAuth(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso por e-mail e senha ou pela conta Google (RF01, RN21). O código de seis dígitos
/// só aparece onde prova a posse do e-mail: confirmação do cadastro e troca de e-mail.
/// Senha, código, validade e limite de envios são do Supabase Auth; aqui só se pede e se
/// confirma. Detalhes em docs/stack.md, seção Autenticação.
class AuthRepositorio {
  AuthRepositorio(this._auth, this._google);

  final GoTrueClient _auth;
  final GoogleSignIn _google;

  /// Sessão atual e cada mudança dela; a primeira emissão é a sessão guardada no aparelho.
  Stream<Session?> get sessoes => _auth.onAuthStateChange.map((estado) => estado.session);

  String? get emailAtual => _auth.currentUser?.email;

  /// Entra com a senha. Devolve false quando o cadastro ainda espera o código, depois de
  /// reenviá-lo: a tela segue então para a confirmação do e-mail.
  Future<bool> entrar(String email, String senha) async {
    try {
      await _auth.signInWithPassword(email: email, password: senha);
      return true;
    } on AuthException catch (e) {
      if (e.code != 'email_not_confirmed') throw _traduzir(e);
    }
    try {
      await _auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      // Um código enviado há menos de um minuto continua valendo: segue para ele.
      if (e.code != 'over_email_send_rate_limit') throw _traduzir(e);
    }
    return false;
  }

  /// Cria a conta pendente e envia o código. O nome vai nos metadados, de onde o gatilho
  /// privado.criar_pessoa monta o perfil na confirmação; sem nome, o banco recusa o cadastro.
  /// E-mail que já tem conta chega como erro ou, se o serviço esconde a conta, como
  /// usuário sem identities; os dois viram a mesma falha.
  Future<void> criarConta(String nome, String email, String senha) => _executar(() async {
        final resposta = await _auth.signUp(email: email, password: senha, data: {'nome': nome});
        if (resposta.user?.identities?.isEmpty ?? false) throw const FalhaAuth(_jaTemConta);
      });

  Future<void> confirmarCadastro(String email, String codigo) =>
      _executar(() => _auth.verifyOTP(type: OtpType.email, email: email, token: codigo));

  Future<void> reenviarConfirmacao(String email) =>
      _executar(() => _auth.resend(type: OtpType.signup, email: email));

  /// Seletor de contas do Android e troca do ID token por sessão, sem navegador.
  /// Fechar o seletor não é erro: volta sem sessão e sem mensagem.
  Future<void> entrarComGoogle() async {
    final GoogleSignInAccount conta;
    try {
      conta = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      throw _traduzirGoogle(e);
    }
    final idToken = conta.authentication.idToken;
    if (idToken == null) throw const FalhaAuth(_falhaGoogle);
    await _executar(() => _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken));
  }

  /// Envia o código ao endereço novo; o antigo só recebe o aviso quando a troca se concluir.
  Future<void> pedirTrocaEmail(String novo) =>
      _executar(() => _auth.updateUser(UserAttributes(email: novo)));

  /// Conclui a troca e derruba as sessões dos outros aparelhos; a deste continua (RNF07).
  /// Os aparelhos de push são apagados pelo gatilho do banco, não por aqui.
  Future<void> confirmarTrocaEmail(String novo, String codigo) => _executar(() async {
        await _auth.verifyOTP(type: OtpType.emailChange, email: novo, token: codigo);
        await _auth.signOut(scope: SignOutScope.others);
      });

  /// Sai também do Google, para o seletor de contas voltar a aparecer na próxima entrada.
  Future<void> sair() => _executar(() async {
        await _auth.signOut();
        await _google.signOut();
      });

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
      'invalid_credentials' => 'E-mail ou senha incorretos.',
      'weak_password' => 'A senha precisa de pelo menos $tamanhoMinimoSenha caracteres.',
      'user_already_exists' => _jaTemConta,
      'same_password' => 'A senha nova precisa ser diferente da atual.',
      'over_email_send_rate_limit' => 'Aguarde um minuto antes de pedir outro código.',
      'over_request_rate_limit' => 'Muitas tentativas seguidas. Aguarde alguns minutos.',
      'otp_expired' => 'Código inválido ou vencido. Confira ou peça outro.',
      'email_exists' => 'Esse e-mail já pertence a outra conta.',
      'email_address_invalid' || 'validation_failed' => 'Confira o e-mail digitado.',
      _ => 'Não foi possível concluir agora. Tente de novo.',
    });
  }

  // Os códigos do google_sign_in 7.2.0. O de SHA-1 sem cadastro no cliente Android se
  // confere no aparelho (T07, cenário 22).
  FalhaAuth _traduzirGoogle(GoogleSignInException e) => FalhaAuth(switch (e.code) {
        GoogleSignInExceptionCode.interrupted || GoogleSignInExceptionCode.uiUnavailable =>
          'Não foi possível abrir a tela do Google agora. Tente de novo.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'A entrada pelo Google não está configurada neste aparelho. Entre com e-mail e senha.',
        _ => _falhaGoogle,
      });
}

final authRepositorioProvider = Provider<AuthRepositorio>(
  (ref) => AuthRepositorio(Supabase.instance.client.auth, GoogleSignIn.instance),
);

final sessaoProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositorioProvider).sessoes);
