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
}
