import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/router/app_router.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/core/theme/app_theme.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/l10n/app_localizations.dart';

import '../../helpers/fakes.dart';
import '../../helpers/test_app.dart';

/// Cenários S10 e S11 (rota de quem entrou só pelo Google) de
/// docs/testes-referencia.md, seção 10.4. O roteador é o real.
void main() {
  setUpAll(registerFakes);

  late MockAuthRepository auth;
  late MockTermsRepository terms;
  late MockProfileRepository profile;

  setUp(() {
    auth = MockAuthRepository();
    terms = MockTermsRepository();
    profile = MockProfileRepository();
    when(() => auth.hasSession).thenReturn(true);
    when(() => auth.currentUserId).thenReturn(anaId);
    when(() => auth.currentEmail).thenReturn('ana@voleiin.test');
    when(() => auth.hasEmailPassword).thenReturn(true);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => profile.fetchOwn()).thenAnswer((_) async => ownProfile());
  });

  void currentTerms(List<TermsVersion> current, List<TermsVersion> accepted) {
    when(() => terms.fetchStatus()).thenAnswer(
      (_) async => TermsStatus.compare(current: current, accepted: accepted),
    );
  }

  Future<GoRouter> pumpApp(WidgetTester tester, {String? location}) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        termsRepositoryProvider.overrideWithValue(terms),
        profileRepositoryProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: appTheme,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) {
      router.go(location);
      await tester.pumpAndSettle();
    }
    return router;
  }

  String pathOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('S10a: sessão sem aceite vai para /terms', (tester) async {
    currentTerms(const [termsOfUse10, privacy10], const []);
    final router = await pumpApp(tester);
    expect(pathOf(router), Routes.termsPath);
    expect(find.text(l10nPt.termsSubtitleFirst), findsOneWidget);
  });

  testWidgets('S10b: sessão com aceite da versão vigente vai para /games', (
    tester,
  ) async {
    currentTerms(
      const [termsOfUse10, privacy10],
      const [termsOfUse10, privacy10],
    );
    final router = await pumpApp(tester);
    expect(pathOf(router), Routes.gamesPath);
  });

  testWidgets(
    'S10c: vigente 1.1 e aceite 1.0 vai para /terms com a frase de atualização',
    (tester) async {
      currentTerms(
        const [termsOfUse11, privacy10],
        const [termsOfUse10, privacy10],
      );
      final router = await pumpApp(tester);
      expect(pathOf(router), Routes.termsPath);
      expect(find.text(l10nPt.termsSubtitleUpdated), findsOneWidget);
    },
  );

  testWidgets('S10d: com sessão, abrir /signup leva a /games', (tester) async {
    currentTerms(
      const [termsOfUse10, privacy10],
      const [termsOfUse10, privacy10],
    );
    final router = await pumpApp(tester, location: Routes.signupPath);
    expect(pathOf(router), Routes.gamesPath);
  });

  testWidgets(
    'S11c: conta só com Google abrindo /profile/email volta ao perfil',
    (tester) async {
      when(() => auth.hasEmailPassword).thenReturn(false);
      when(() => profile.fetchOwn())
          .thenAnswer((_) async => ownProfile(hasEmailPassword: false));
      currentTerms(
        const [termsOfUse10, privacy10],
        const [termsOfUse10, privacy10],
      );
      final router = await pumpApp(tester, location: Routes.profileEmailPath);
      expect(pathOf(router), Routes.profilePath);
    },
  );
}
