import 'package:freezed_annotation/freezed_annotation.dart';

part 'terms.freezed.dart';
part 'terms.g.dart';

/// Documento legal (enum `legal_document`, docs/modelo-dados.md, seção 3).
enum LegalDocument {
  @JsonValue('terms_of_use')
  termsOfUse,
  @JsonValue('privacy_policy')
  privacyPolicy;

  /// Valor do banco, usado também na rota `/terms/:document`.
  String get dbValue => switch (this) {
    LegalDocument.termsOfUse => 'terms_of_use',
    LegalDocument.privacyPolicy => 'privacy_policy',
  };

  static LegalDocument? fromDbValue(String value) {
    for (final document in values) {
      if (document.dbValue == value) return document;
    }
    return null;
  }
}

/// Uma linha de `current_terms_versions()` ou de `terms_acceptances`.
@freezed
abstract class TermsVersion with _$TermsVersion {
  const factory TermsVersion({
    required LegalDocument document,
    required String version,
  }) = _TermsVersion;

  factory TermsVersion.fromJson(Map<String, dynamic> json) =>
      _$TermsVersionFromJson(json);
}

/// Resultado da conferência dos termos (RF105, docs/ui/telas.md, 3.1).
///
/// [current] são as versões vigentes, na ordem do servidor; [missing], as que a
/// pessoa ainda não aceitou. [hadPreviousAcceptance] escolhe a frase da tela.
@freezed
abstract class TermsStatus with _$TermsStatus {
  const TermsStatus._();

  const factory TermsStatus({
    required List<TermsVersion> current,
    required List<TermsVersion> missing,
    required bool hadPreviousAcceptance,
  }) = _TermsStatus;

  /// Compara as versões vigentes com os aceites da pessoa.
  factory TermsStatus.compare({
    required List<TermsVersion> current,
    required List<TermsVersion> accepted,
  }) {
    final missing = current.where((v) => !accepted.contains(v)).toList();
    final missingDocs = missing.map((v) => v.document).toSet();
    return TermsStatus(
      current: current,
      missing: missing,
      hadPreviousAcceptance: accepted.any(
        (a) => missingDocs.contains(a.document),
      ),
    );
  }

  bool get accepted => missing.isEmpty;
}
