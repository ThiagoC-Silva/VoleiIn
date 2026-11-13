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

  test('os textos dos erros da fatia 2 são os do catálogo (docs/copy.md)', () {
    // Seção 5.5: o texto deixou de citar o link (ADR 0017).
    expect(
      errorText(l10nPt, ErrorCode.authEmailNotConfirmed),
      'Confirme o seu e-mail antes de entrar.',
    );
    // Seção 6.8.
    expect(
      errorText(l10nPt, ErrorCode.authInvalidCode),
      'Código incorreto ou vencido. Confira ou peça um novo.',
    );
    expect(
      errorText(l10nPt, ErrorCode.authGoogleFailed),
      'Não foi possível entrar com o Google. Tente de novo.',
    );
    expect(
      errorText(l10nPt, ErrorCode.pixKeyInUse),
      'Você pode trocar a chave, mas não removê-la enquanto tiver jogos em '
      'aberto ou valores a receber.',
    );
    expect(
      errorText(l10nPt, ErrorCode.photoTooLarge),
      'A foto passa de 2 MB. Escolha outra.',
    );
    expect(
      errorText(l10nPt, ErrorCode.photoInvalidType),
      'Use uma foto JPEG, PNG ou WebP.',
    );
  });
}
