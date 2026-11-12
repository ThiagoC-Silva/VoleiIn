import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/legal_document.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/features/auth/presentation/terms_screen.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenário S09 de docs/testes-referencia.md, seção 10.4
/// (docs/ui/telas.md, 5.5 e 5.6).
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness();
    h.signedIn();
  });

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(buttonWithText<FilledButton>(l10nPt.termsAcceptButton));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'S09: sem aceite, o botão só habilita com a caixa marcada e grava uma linha por documento',
    (tester) async {
      h.termsAccepted(accepted: null);
      when(() => h.terms.accept(any())).thenAnswer((_) async {
        // O servidor passa a devolver o aceite gravado.
        h.termsAccepted();
      });
      await h.pumpApp(tester);

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.text(l10nPt.termsSubtitleFirst), findsOneWidget);
      expect(find.text(l10nPt.termsDocumentTermsOfUse), findsOneWidget);
      expect(find.text(l10nPt.termsDocumentPrivacyPolicy), findsOneWidget);
      expect(find.text(l10nPt.termsVersion('1.0')), findsNWidgets(2));
      expect(
        isEnabled<FilledButton>(tester, l10nPt.termsAcceptButton),
        isFalse,
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(
        isEnabled<FilledButton>(tester, l10nPt.termsAcceptButton),
        isTrue,
      );

      await accept(tester);

      final accepted =
          verify(() => h.terms.accept(captureAny())).captured.single
              as List<TermsVersion>;
      expect(accepted, unorderedEquals([termsOfUse10, privacyPolicy10]));
      expect(h.location, '/games');
    },
  );

  testWidgets('aceita só o documento que falta', (tester) async {
    when(() => h.terms.ownAcceptances()).thenAnswer((_) async => [termsOfUse10]);
    when(() => h.terms.accept(any())).thenAnswer((_) async => h.termsAccepted());
    await h.pumpApp(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await accept(tester);

    final accepted =
        verify(() => h.terms.accept(captureAny())).captured.single
            as List<TermsVersion>;
    expect(accepted, [privacyPolicy10]);
  });

  testWidgets('erro ao aceitar vira SnackBar, e a caixa continua marcada', (
    tester,
  ) async {
    h.termsAccepted(accepted: null);
    when(
      () => h.terms.accept(any()),
    ).thenThrow(const AppException(ErrorCode.noConnection));
    await h.pumpApp(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await accept(tester);

    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(h.location, '/terms');
  });

  testWidgets(
    'versão trocada entre abrir e aceitar: relê as versões e desmarca a caixa',
    (tester) async {
      h.termsAccepted(accepted: null);
      when(() => h.terms.accept(any())).thenAnswer((_) async {
        // O RLS recusa a versão antiga (42501), e o servidor já tem a 1.1.
        h.termsAccepted(current: '1.1', accepted: null);
        throw const AppException(ErrorCode.internalError);
      });
      await h.pumpApp(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await accept(tester);

      expect(find.text(l10nPt.termsVersion('1.1')), findsNWidgets(2));
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(h.location, '/terms');
    },
  );

  testWidgets('falha na conferência mostra o erro com Tentar de novo', (
    tester,
  ) async {
    when(
      () => h.terms.currentVersions(),
    ).thenThrow(const AppException(ErrorCode.noConnection));
    await h.pumpApp(tester);

    expect(h.location, '/terms');
    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);

    h.termsAccepted();
    await tester.tap(find.text(l10nPt.commonTryAgain));
    await tester.pumpAndSettle();

    expect(h.location, '/games');
  });

  testWidgets('a linha do documento abre o texto, e o voltar retorna', (
    tester,
  ) async {
    h.termsAccepted(accepted: null);
    await h.pumpApp(tester);

    await tester.tap(find.text(l10nPt.termsDocumentPrivacyPolicy));
    await tester.pumpAndSettle();

    expect(h.location, '/terms/${LegalDocument.privacyPolicy.value}');
    expect(find.text(l10nPt.termsPlaceholderBody), findsOneWidget);

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();
    expect(h.location, '/terms');
  });

  testWidgets('documento desconhecido mostra "não encontrado"', (tester) async {
    h.termsAccepted(accepted: null);
    await h.pumpApp(tester, location: '/terms/outro');

    expect(find.text(l10nPt.errorNotFound), findsOneWidget);
  });

  testWidgets('Sair encerra a sessão', (tester) async {
    h.termsAccepted(accepted: null);
    await h.pumpApp(tester);

    await tester.tap(find.text(l10nPt.authLogout));
    await tester.pumpAndSettle();

    verify(() => h.auth.signOut()).called(1);
  });
}
