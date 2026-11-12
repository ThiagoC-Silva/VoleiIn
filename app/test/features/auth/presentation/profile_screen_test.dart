import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/presentation/profile_screen.dart';

import '../../../helpers/harness.dart';
import '../../../helpers/test_app.dart';

/// Cenários S11 e S17 de docs/testes-referencia.md, seção 10.4
/// (docs/ui/telas.md, 5.7).
void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  testWidgets('S11: conta só com Google não vê Trocar e-mail nem Trocar senha', (
    tester,
  ) async {
    h.signedIn(email: 'ana.souza@gmail.com', hasEmailAccess: false);

    await h.pumpApp(tester, location: '/profile');

    expect(find.text(l10nPt.profileEdit), findsOneWidget);
    expect(find.text(l10nPt.profilePix), findsOneWidget);
    expect(find.text(l10nPt.profileChangeEmail), findsNothing);
    expect(find.text(l10nPt.profileChangePassword), findsNothing);
  });

  testWidgets('S11: conta com e-mail e senha vê as duas linhas', (tester) async {
    h.signedIn();

    await h.pumpApp(tester, location: '/profile');

    expect(find.text(l10nPt.profileChangeEmail), findsOneWidget);
    expect(find.text(l10nPt.profileChangePassword), findsOneWidget);
  });

  testWidgets(
    'S11: conta só com Google abrindo /profile/email ou /profile/password volta ao perfil',
    (tester) async {
      h.signedIn(hasEmailAccess: false);
      await h.pumpApp(tester, location: '/profile');

      await h.go(tester, '/profile/email');
      expect(h.location, '/profile');

      await h.go(tester, '/profile/password');
      expect(h.location, '/profile');
      expect(find.byType(ProfileScreen), findsOneWidget);
    },
  );

  testWidgets('S17: o cabeçalho mostra o apelido no lugar do nome (RN100)', (
    tester,
  ) async {
    h.signedIn(email: 'ana@exemplo.com');
    h.ownProfile(name: 'Ana Souza', nickname: 'Aninha');

    await h.pumpApp(tester, location: '/profile');

    expect(find.text('Aninha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('ana@exemplo.com'), findsOneWidget);
  });

  testWidgets('a linha da chave Pix mostra o tipo e a chave formatada', (
    tester,
  ) async {
    h.signedIn();
    h.ownProfile(pixKeyType: PixKeyType.cpf, pixKey: '52998224725');

    await h.pumpApp(tester, location: '/profile');

    expect(
      find.text(l10nPt.profilePixSummary(l10nPt.pixTypeCpf, '529.982.247-25')),
      findsOneWidget,
    );
  });

  testWidgets('sem chave Pix, a linha diz "Não cadastrada"', (tester) async {
    h.signedIn();

    await h.pumpApp(tester, location: '/profile');

    expect(find.text(l10nPt.profilePixNone), findsOneWidget);
    expect(find.text(l10nPt.profileEditSubtitle), findsOneWidget);
  });

  testWidgets('falha ao carregar mostra o estado de erro e tenta de novo', (
    tester,
  ) async {
    h.signedIn();
    when(
      () => h.profiles.fetchOwn(),
    ).thenThrow(const AppException(ErrorCode.noConnection));

    await h.pumpApp(tester, location: '/profile');
    expect(find.text(l10nPt.errorNoConnection), findsOneWidget);

    h.ownProfile(name: 'Ana Souza');
    await tester.tap(find.text(l10nPt.commonTryAgain));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
  });

  testWidgets('Sair encerra a sessão, sem pedir confirmação', (tester) async {
    h.signedIn();
    await h.pumpApp(tester, location: '/profile');

    await tester.tap(find.text(l10nPt.authLogout));
    await tester.pumpAndSettle();

    verify(() => h.auth.signOut()).called(1);
  });

  testWidgets('as linhas abrem as telas de edição', (tester) async {
    h.signedIn();
    await h.pumpApp(tester, location: '/profile');

    await tester.tap(find.text(l10nPt.profileEdit));
    await tester.pumpAndSettle();
    expect(h.location, '/profile/edit');

    await tester.tap(find.byTooltip(l10nPt.commonBack));
    await tester.pumpAndSettle();
    expect(h.location, '/profile');

    await tester.tap(find.text(l10nPt.profilePix));
    await tester.pumpAndSettle();
    expect(h.location, '/profile/pix');
  });
}
