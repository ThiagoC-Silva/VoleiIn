import 'package:json_annotation/json_annotation.dart';

/// Enum `legal_document` do banco (docs/modelo-dados.md, seção 3).
enum LegalDocument {
  @JsonValue('terms_of_use')
  termsOfUse('terms_of_use'),
  @JsonValue('privacy_policy')
  privacyPolicy('privacy_policy');

  const LegalDocument(this.value);

  /// Valor do banco, usado também na rota `/terms/:document`.
  final String value;

  /// Nulo para um valor que não é documento (rota com outro `:document`).
  static LegalDocument? fromValue(String value) {
    for (final document in values) {
      if (document.value == value) return document;
    }
    return null;
  }
}
