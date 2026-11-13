import 'package:freezed_annotation/freezed_annotation.dart';

import 'legal_document.dart';

part 'terms.freezed.dart';
part 'terms.g.dart';

/// Versão de um documento: a vigente, de `current_terms_versions()`, ou a
/// aceita, de `terms_acceptances` (docs/contratos-api.md, seção 9).
@freezed
abstract class TermsVersion with _$TermsVersion {
  const factory TermsVersion({
    required LegalDocument document,
    required String version,
  }) = _TermsVersion;

  factory TermsVersion.fromJson(Map<String, dynamic> json) =>
      _$TermsVersionFromJson(json);
}

/// Resultado da conferência dos termos (docs/ui/telas.md, 3.1 e 5.5). Montado
/// no provider, não vem de JSON.
@freezed
abstract class TermsStatus with _$TermsStatus {
  const factory TermsStatus({
    /// Versão vigente de cada documento.
    required List<TermsVersion> current,

    /// Versões vigentes que a pessoa ainda não aceitou.
    required List<TermsVersion> missing,

    /// Se a pessoa já aceitou uma versão anterior de algum documento que
    /// falta. Muda a frase de apoio da `/terms`.
    required bool hadPreviousAcceptance,
  }) = _TermsStatus;

  const TermsStatus._();

  /// Calcula o que falta a partir das versões vigentes e dos aceites.
  factory TermsStatus.from({
    required List<TermsVersion> current,
    required List<TermsVersion> accepted,
  }) {
    final missing = [
      for (final version in current)
        if (!accepted.contains(version)) version,
    ];
    final previous = missing.any(
      (m) => accepted.any((a) => a.document == m.document),
    );
    return TermsStatus(
      current: current,
      missing: missing,
      hadPreviousAcceptance: previous,
    );
  }

  bool get upToDate => missing.isEmpty;
}
