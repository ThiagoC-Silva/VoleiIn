import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/shared/widgets/bottom_nav.dart';

import '../../helpers/fakes.dart'
    show
        MockProfileRepository,
        MockTermsRepository,
        ownProfile,
        privacy10,
        termsOfUse10;
import '../../helpers/test_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Cenário L05 de docs/testes-referencia.md, seção 9.4, e a lista de
/// acessibilidade das abas (L04).
void main() {
  late MockAuthRepository repository;
  late MockTermsRepository terms;
  late MockProfileRepository profile;

  setUp(() {
    // A aba Perfil lê o próprio perfil desde a fatia 2.
    profile = MockProfileRepository();
    when(() => profile.fetchOwn()).thenAnswer((_) async => ownProfile());
    repository = MockAuthRepository();
    // Usuário logado, que já aceitou os termos na versão vigente: sem o
    // aceite, a fatia 2 leva à /terms (cenário S10).
    terms = MockTermsRepository();
    when(() => terms.fetchStatus()).thenAnswer(
      (_) async => TermsStatus.compare(
        current: const [termsOfUse10, privacy10],
        accepted: const [termsOfUse10, privacy10],
      ),
    );
    when(() => repository.currentUserId)
        .thenReturn('00000000-0000-0000-0000-00000000000a');
    when(() => repository.hasSession).thenReturn(true);
    when(() => repository.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          termsRepositoryProvider.overrideWithValue(terms),
          profileRepositoryProvider.overrideWithValue(profile),
        ],
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder navLabel(String text) => find.descendant(
    of: find.byType(VoleiBottomNav),
    matching: find.text(text),
  );

  testWidgets('L05: abre na aba Jogos, com as quatro abas na ordem do mapa', (
    tester,
  ) async {
    await pumpApp(tester);

    for (final label in [
      l10nPt.navGames,
      l10nPt.navGroups,
      l10nPt.navCharges,
      l10nPt.navProfile,
    ]) {
      expect(navLabel(label), findsOneWidget, reason: label);
    }

    final positions = [
      tester.getCenter(navLabel(l10nPt.navGames)).dx,
      tester.getCenter(navLabel(l10nPt.navGroups)).dx,
      tester.getCenter(navLabel(l10nPt.navCharges)).dx,
      tester.getCenter(navLabel(l10nPt.navProfile)).dx,
    ];
    expect(positions, orderedEquals(List.of(positions)..sort()));

    // Abre na aba Jogos.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10nPt.navGames),
      ),
      findsOneWidget,
    );
  });

  testWidgets('L05: trocar de aba não empilha telas', (tester) async {
    await pumpApp(tester);

    await tester.tap(navLabel(l10nPt.navGroups));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10nPt.navGroups),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(navLabel(l10nPt.navProfile));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authLogout), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('L04: as abas com a fonte do sistema em 150% não estouram', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    expect(tester.takeException(), isNull);

    for (final label in [
      l10nPt.navGroups,
      l10nPt.navCharges,
      l10nPt.navProfile,
    ]) {
      await tester.tap(navLabel(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
