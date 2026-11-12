import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voleiin/app.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/shared/widgets/bottom_nav.dart';

import '../../helpers/test_app.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Cenário L05 de docs/testes-referencia.md, seção 9.4, e a lista de
/// acessibilidade das abas (L04).
void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.hasSession).thenReturn(true);
    when(() => repository.onAuthStateChange)
        .thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder navLabel(String text) => find.descendant(
        of: find.byType(VoleiBottomNav),
        matching: find.text(text),
      );

  testWidgets('L05: abre na aba Jogos, com as quatro abas na ordem do mapa',
      (tester) async {
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
      find.descendant(of: find.byType(AppBar), matching: find.text(l10nPt.navGames)),
      findsOneWidget,
    );
  });

  testWidgets('L05: trocar de aba não empilha telas', (tester) async {
    await pumpApp(tester);

    await tester.tap(navLabel(l10nPt.navGroups));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(l10nPt.navGroups)),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(navLabel(l10nPt.navProfile));
    await tester.pumpAndSettle();

    expect(find.text(l10nPt.authLogout), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('L04: as abas com a fonte do sistema em 150% não estouram',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);
    expect(tester.takeException(), isNull);

    for (final label in [l10nPt.navGroups, l10nPt.navCharges, l10nPt.navProfile]) {
      await tester.tap(navLabel(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });
}
