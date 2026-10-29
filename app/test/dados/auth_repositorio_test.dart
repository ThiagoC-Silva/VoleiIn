import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/dados/auth_repositorio.dart';

/// Serviço que recusa toda troca de senha com o [codigo] dado.
class _AuthRecusaSenha extends Fake implements GoTrueClient {
  _AuthRecusaSenha(this.codigo);

  final String codigo;

  @override
  Future<UserResponse> updateUser(UserAttributes attributes, {String? emailRedirectTo}) =>
      throw AuthException('recusada', statusCode: '422', code: codigo);
}

/// Serviço com o cadastro pendente, que recusa todo reenvio do código com o [texto] dado.
class _AuthRecusaReenvio extends Fake implements GoTrueClient {
  _AuthRecusaReenvio(this.texto);

  final String texto;

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) =>
      throw const AuthException('Email not confirmed', statusCode: '400', code: 'email_not_confirmed');

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) =>
      throw AuthException(texto, statusCode: '429', code: 'over_email_send_rate_limit');
}

void main() {
  // Os textos são os que o Play Services devolveu no aparelho (T07, cenário 22).
  GoogleSignInException cancelada(String descricao) =>
      GoogleSignInException(code: GoogleSignInExceptionCode.canceled, description: descricao);

  test('fechar o seletor volta sem mensagem', () {
    expect(traduzirGoogle(cancelada('[16] Cancelled by user.')), isNull);
  });

  test('chave sem cadastro, também canceled, mostra a falha genérica', () {
    expect(
      traduzirGoogle(cancelada('[16] Account reauth failed.'))?.mensagem,
      'Não foi possível entrar com o Google. Entre com e-mail e senha.',
    );
  });

  test('canceled sem descrição mostra a falha genérica', () {
    expect(
      traduzirGoogle(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled))
          ?.mensagem,
      'Não foi possível entrar com o Google. Entre com e-mail e senha.',
    );
  });

  test('configuração ausente aponta o e-mail e senha', () {
    expect(
      traduzirGoogle(
        const GoogleSignInException(code: GoogleSignInExceptionCode.providerConfigurationError),
      )?.mensagem,
      'A entrada pelo Google não está configurada neste aparelho. Entre com e-mail e senha.',
    );
  });

  group('senha da A2 gravada depois do código', () {
    AuthRepositorio repositorio(String codigo) => AuthRepositorio(_AuthRecusaSenha(codigo), GoogleSignIn.instance);

    test('same_password é o caso comum, sem cadastro anterior, e não é falha', () async {
      await repositorio('same_password').gravarSenhaDoCadastro('segredo123');
    });

    test('outra recusa chega traduzida', () async {
      await expectLater(
        repositorio('weak_password').gravarSenhaDoCadastro('segredo123'),
        throwsA(isA<FalhaAuth>().having((f) => f.mensagem, 'mensagem', contains('8 caracteres'))),
      );
    });
  });

  // Os textos são os do serviço na v2.197.0: o do intervalo, sondado no local, e o do teto,
  // visto no remoto (T09.8).
  group('intervalo de 60 s e teto por hora, com o mesmo código', () {
    const intervalo = 'For security purposes, you can only request this after 59 seconds.';
    const teto = 'email rate limit exceeded';
    const aguarde = 'Aguarde um minuto antes de pedir outro código.';
    const muitos = 'Muitos códigos enviados agora. Tente de novo em até uma hora.';

    AuthRepositorio repositorio(String texto) => AuthRepositorio(_AuthRecusaReenvio(texto), GoogleSignIn.instance);
    Matcher falha(String mensagem) => throwsA(isA<FalhaAuth>().having((f) => f.mensagem, 'mensagem', mensagem));

    test('no intervalo, a entrada de cadastro pendente segue para o código anterior', () async {
      expect(await repositorio(intervalo).entrar('carla@exemplo.com', 'segredo123'), isFalse);
      expect(
        await repositorio('For security purposes, you can only request this after 1 second.')
            .entrar('carla@exemplo.com', 'segredo123'),
        isFalse,
      );
    });

    test('no teto, a entrada de cadastro pendente para na mensagem', () async {
      await expectLater(repositorio(teto).entrar('carla@exemplo.com', 'segredo123'), falha(muitos));
    });

    test('o reenvio no intervalo pede um minuto, e no teto aponta a hora', () async {
      await expectLater(repositorio(intervalo).reenviarConfirmacao('carla@exemplo.com'), falha(aguarde));
      await expectLater(repositorio(teto).reenviarConfirmacao('carla@exemplo.com'), falha(muitos));
    });

    test('texto que não diz os segundos conta como teto', () async {
      await expectLater(
        repositorio('Too many emails, slow down.').entrar('carla@exemplo.com', 'segredo123'),
        falha(muitos),
      );
    });
  });
}
