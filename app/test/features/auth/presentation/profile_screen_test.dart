import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/domain/pix_key_type.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/presentation/profile_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_router.dart';

/// Cenários S11 e S17 de docs/testes-referencia.md, seção 10.4.
void main() {
  late MockProfileRepository profile;

  setUp(() => profile = MockProfileRepository());

  Future<void> pump(WidgetTester tester, OwnProfile data) {
    when(() => profile.fetchOwn()).thenAnswer((_) async => data);
    return pumpRouterApp(
      tester,
      initialLocation: Routes.profilePath,
      overrides: [
        profileRepositoryProvider.overrideWithValue(profile),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
      screens: {Routes.profile: (_) => const ProfileScreen()},
    );
  }

  testWidgets(
    'S11a: conta só com Google não mostra Trocar e-mail e Trocar senha',
    (tester) async {
      await pump(tester, ownProfile(hasEmailPassword: false));
      expect(find.text(l10nPt.profileEdit), findsOneWidget);
      expect(find.text(l10nPt.profilePix), findsOneWidget);
      expect(find.text(l10nPt.profileChangeEmail), findsNothing);
      expect(find.text(l10nPt.profileChangePassword), findsNothing);
    },
  );

  testWidgets('S11b: conta com e-mail mostra as duas linhas', (tester) async {
    await pump(tester, ownProfile(hasEmailPassword: true));
    expect(find.text(l10nPt.profileChangeEmail), findsOneWidget);
    expect(find.text(l10nPt.profileChangePassword), findsOneWidget);
  });

  testWidgets('S17: o cabeçalho mostra o apelido (RN100)', (tester) async {
    await pump(tester, ownProfile(name: 'Ana Souza', nickname: 'Aninha'));
    expect(find.text('Aninha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);
    expect(find.text('ana@voleiin.test'), findsOneWidget);
  });

  testWidgets('a linha da chave Pix mostra o tipo e a chave formatada', (
    tester,
  ) async {
    await pump(
      tester,
      ownProfile(pixKeyType: PixKeyType.cpf, pixKey: '52998224725'),
    );
    expect(
      find.text(l10nPt.profilePixSummary('CPF', '529.982.247-25')),
      findsOneWidget,
    );
  });

  testWidgets('sem chave, a linha diz Não cadastrada', (tester) async {
    await pump(tester, ownProfile());
    expect(find.text(l10nPt.profilePixNone), findsOneWidget);
  });
}
