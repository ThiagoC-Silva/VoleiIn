import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/features/auth/presentation/terms_screen.dart';

import '../../helpers/harness.dart';
import '../../helpers/test_app.dart';

/// Cenário S10 de docs/testes-referencia.md, seção 10.4: os redirecionamentos
/// de docs/ui/telas.md, 3.1.
void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  testWidgets('S10: sessão sem aceite vai para /terms', (tester) async {
    h.signedIn();
    h.termsAccepted(accepted: null);

    await h.pumpApp(tester);

    expect(h.location, '/terms');
    expect(find.text(l10nPt.termsSubtitleFirst), findsOneWidget);
  });

  testWidgets('S10: sessão com aceite da versão vigente vai para /games', (
    tester,
  ) async {
    h.signedIn();
    h.termsAccepted();

    await h.pumpApp(tester);

    expect(h.location, '/games');
    expect(find.byType(TermsScreen), findsNothing);
  });

  testWidgets(
    'S10: vigente 1.1 e aceite 1.0 vai para /terms, com a frase de atualização',
    (tester) async {
      h.signedIn();
      h.termsAccepted(current: '1.1', accepted: '1.0');

      await h.pumpApp(tester);

      expect(h.location, '/terms');
      expect(find.text(l10nPt.termsSubtitleUpdated), findsOneWidget);
      expect(find.text(l10nPt.termsVersion('1.1')), findsNWidgets(2));
    },
  );

  testWidgets('S10: com sessão, abrir /signup leva a /games', (tester) async {
    h.signedIn();
    h.termsAccepted();

    await h.pumpApp(tester, location: '/signup');

    expect(h.location, '/games');
  });

  testWidgets('sem sessão, uma rota do app leva ao login', (tester) async {
    await h.pumpApp(tester, location: '/profile');

    expect(h.location, '/login');
  });

  testWidgets('sem sessão, as rotas de acesso abrem', (tester) async {
    await h.pumpApp(tester, location: '/signup');
    expect(h.location, '/signup');

    await h.go(tester, '/forgot-password');
    expect(h.location, '/forgot-password');
  });

  testWidgets('sem aceite, as rotas do app continuam fechadas', (tester) async {
    h.signedIn();
    h.termsAccepted(accepted: null);

    await h.pumpApp(tester, location: '/profile');

    expect(h.location, '/terms');
  });
}
