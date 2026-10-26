import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:voleiin/dados/auth_repositorio.dart';

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
}
