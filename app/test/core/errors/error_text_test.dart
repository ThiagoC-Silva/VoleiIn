import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/errors/error_text.dart';

import '../../helpers/test_app.dart';

/// Cenário E08 de docs/testes-referencia.md, seção 9.4: cada ErrorCode tem
/// texto no app_pt.arb, e nenhum é vazio.
void main() {
  test('E08: todo ErrorCode tem texto não vazio', () {
    for (final code in ErrorCode.values) {
      expect(errorText(l10nPt, code), isNotEmpty, reason: code.name);
    }
  });

  test(
    'os textos dos erros da fatia 2 são os do catálogo (docs/copy.md, 6.8)',
    () {
      const expected = {
        ErrorCode.authEmailNotConfirmed:
            'Confirme o seu e-mail antes de entrar.',
        ErrorCode.authWeakPassword:
            'A senha precisa ter pelo menos 8 caracteres.',
        ErrorCode.authInvalidCode:
            'Código incorreto ou vencido. Confira ou peça um novo.',
        ErrorCode.authInvalidEmail: 'Confira o e-mail informado.',
        ErrorCode.authEmailInUse: 'Este e-mail já é usado por outra conta.',
        ErrorCode.authSamePassword:
            'A nova senha precisa ser diferente da atual.',
        ErrorCode.authEmailRateLimited:
            'Muitos e-mails enviados. Espere alguns minutos e tente de novo.',
        ErrorCode.authGoogleFailed:
            'Não foi possível entrar com o Google. Tente de novo.',
        ErrorCode.pixKeyInUse: 'Você pode trocar a chave, mas não removê-la enquanto tiver jogos em aberto ou valores a receber.',
        ErrorCode.photoTooLarge: 'A foto passa de 2 MB. Escolha outra.',
        ErrorCode.photoInvalidType: 'Use uma foto JPEG, PNG ou WebP.',
      };
      for (final entry in expected.entries) {
        expect(
          errorText(l10nPt, entry.key),
          entry.value,
          reason: entry.key.name,
        );
      }
    },
  );

  test('os textos dos erros gerais são os do catálogo (docs/copy.md, 5.5)', () {
    expect(
      errorText(l10nPt, ErrorCode.notFound),
      'Não encontramos o que você procura.',
    );
    expect(
      errorText(l10nPt, ErrorCode.authInvalidCredentials),
      'E-mail ou senha incorretos.',
    );
  });
}
