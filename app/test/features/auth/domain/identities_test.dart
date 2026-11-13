import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/domain/identities.dart';
import 'package:voleiin/features/auth/domain/terms.dart';

void main() {
  // Cenário U07 de docs/testes-referencia.md, seção 10.4.
  test('U07: tem acesso por e-mail e senha', () {
    expect(hasEmailPassword(['email']), isTrue);
    expect(hasEmailPassword(['google']), isFalse);
    expect(hasEmailPassword(['email', 'google']), isTrue);
  });

  // Base dos cenários S09 e S10: a conferência que leva à /terms (RF105).
  group('TermsStatus.compare', () {
    const terms10 = TermsVersion(document: LegalDocument.termsOfUse, version: '1.0');
    const privacy10 = TermsVersion(document: LegalDocument.privacyPolicy, version: '1.0');
    const terms11 = TermsVersion(document: LegalDocument.termsOfUse, version: '1.1');

    test('sem aceite: faltam os dois, primeira vez', () {
      final status = TermsStatus.compare(current: [terms10, privacy10], accepted: []);
      expect(status.missing, [terms10, privacy10]);
      expect(status.hadPreviousAcceptance, isFalse);
    });

    test('com aceite da versão vigente: nada falta', () {
      final status = TermsStatus.compare(
        current: [terms10, privacy10],
        accepted: [terms10, privacy10],
      );
      expect(status.accepted, isTrue);
    });

    test('vigente 1.1 e aceite 1.0: falta um, com aceite anterior', () {
      final status = TermsStatus.compare(
        current: [terms11, privacy10],
        accepted: [terms10, privacy10],
      );
      expect(status.missing, [terms11]);
      expect(status.hadPreviousAcceptance, isTrue);
    });
  });
}
