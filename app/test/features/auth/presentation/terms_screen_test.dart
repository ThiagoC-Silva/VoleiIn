import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/features/auth/presentation/terms_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenário S09 de docs/testes-referencia.md, seção 10.4.
void main() {
  setUpAll(registerFakes);

  testWidgets(
    'S09: aceite habilita com a caixa e grava uma linha por documento',
    (tester) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUserId).thenReturn(anaId);
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
      final terms = MockTermsRepository();
      var accepted = false;
      when(() => terms.fetchStatus()).thenAnswer(
        (_) async => TermsStatus.compare(
          current: const [termsOfUse10, privacy10],
          accepted: accepted ? const [termsOfUse10, privacy10] : const [],
        ),
      );
      when(() => terms.accept(any())).thenAnswer((_) async => accepted = true);

      await pumpRouterApp(
        tester,
        initialLocation: Routes.termsPath,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          termsRepositoryProvider.overrideWithValue(terms),
        ],
        screens: {Routes.terms: (_) => const TermsScreen()},
      );

      expect(find.text(l10nPt.termsSubtitleFirst), findsOneWidget);
      expect(find.text(l10nPt.termsVersion('1.0')), findsNWidgets(2));
      final accept = find.widgetWithText(
        FilledButton,
        l10nPt.termsAcceptButton,
      );
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);

      await tapVisible(tester, find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);

      await tapVisible(tester, accept);
      await tester.pumpAndSettle();

      verify(() => terms.accept(const [termsOfUse10, privacy10])).called(1);
    },
  );
}
