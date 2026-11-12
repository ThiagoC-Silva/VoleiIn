import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:voleiin/app.dart';
import 'package:voleiin/core/router/app_router.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/legal_document.dart';
import 'package:voleiin/features/auth/domain/own_profile.dart';
import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/domain/profile_private.dart';
import 'package:voleiin/features/auth/domain/terms.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockTermsRepository extends Mock implements TermsRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

const anaId = '00000000-0000-0000-0000-00000000000a';

const termsOfUse10 = TermsVersion(
  document: LegalDocument.termsOfUse,
  version: '1.0',
);
const privacyPolicy10 = TermsVersion(
  document: LegalDocument.privacyPolicy,
  version: '1.0',
);

/// Monta o app inteiro, com o roteador real e os repositórios trocados por
/// dublês (docs/arquitetura-app.md, seção 11). Cada teste diz só o que muda.
class TestHarness {
  TestHarness() {
    registerFallbackValue(PhotoSource.gallery);
    registerFallbackValue(<TermsVersion>[]);
    registerFallbackValue(PixKeyType.cpf);

    when(
      () => auth.onAuthStateChange,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => auth.signOut()).thenAnswer((_) async {});
    signedOut();
    termsAccepted();
    ownProfile();
  }

  final auth = MockAuthRepository();
  final profiles = MockProfileRepository();
  final terms = MockTermsRepository();
  final picker = MockPhotoPicker();

  late final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      termsRepositoryProvider.overrideWithValue(terms),
      photoPickerProvider.overrideWithValue(picker),
    ],
    // Sem repetição automática: quem tenta de novo é a pessoa.
    retry: (_, _) => null,
  );

  GoRouter get router => container.read(routerProvider);

  /// Caminho da tela que está na frente.
  String get location => router.routerDelegate.currentConfiguration.uri.path;

  void signedOut() {
    when(() => auth.hasSession).thenReturn(false);
    when(() => auth.currentUserId).thenReturn(null);
    when(() => auth.currentEmail).thenReturn(null);
    when(() => auth.hasEmailAccess).thenReturn(false);
  }

  void signedIn({
    String email = 'ana@exemplo.com',
    bool hasEmailAccess = true,
  }) {
    when(() => auth.hasSession).thenReturn(true);
    when(() => auth.currentUserId).thenReturn(anaId);
    when(() => auth.currentEmail).thenReturn(email);
    when(() => auth.hasEmailAccess).thenReturn(hasEmailAccess);
  }

  /// Versão vigente dos dois documentos e a versão que a pessoa aceitou.
  /// `accepted: null` é quem nunca aceitou.
  void termsAccepted({String current = '1.0', String? accepted = '1.0'}) {
    when(() => terms.currentVersions()).thenAnswer(
      (_) async => [
        TermsVersion(document: LegalDocument.termsOfUse, version: current),
        TermsVersion(document: LegalDocument.privacyPolicy, version: current),
      ],
    );
    when(() => terms.ownAcceptances()).thenAnswer(
      (_) async => [
        if (accepted != null) ...[
          TermsVersion(document: LegalDocument.termsOfUse, version: accepted),
          TermsVersion(
            document: LegalDocument.privacyPolicy,
            version: accepted,
          ),
        ],
      ],
    );
  }

  void ownProfile({
    String name = 'Ana Souza',
    String? nickname,
    String? photoPath,
    String? phone,
    bool phoneVisible = false,
    PixKeyType? pixKeyType,
    String? pixKey,
  }) {
    when(() => profiles.fetchOwn()).thenAnswer(
      (_) async => OwnProfile(
        profile: Profile(
          id: anaId,
          name: name,
          nickname: nickname,
          displayName: nickname ?? name,
          photoPath: photoPath,
        ),
        private: ProfilePrivate(
          phone: phone,
          phoneVisible: phoneVisible,
          pixKeyType: pixKeyType,
          pixKey: pixKey,
        ),
      ),
    );
    when(() => profiles.avatarUrl(any())).thenAnswer(
      (_) async => 'http://127.0.0.1:54321/storage/v1/object/sign/avatars/x',
    );
  }

  /// Abre o app num celular de 360 x 760 dp e, se pedido, vai à rota.
  Future<void> pumpApp(
    WidgetTester tester, {
    String? location,
    double textScale = 1.0,
    Size size = const Size(360, 760),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VoleiInApp(),
      ),
    );
    await tester.pumpAndSettle();

    if (location != null) await go(tester, location);
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  /// Empilha a rota sobre a atual, como faz o toque numa linha ou num botão.
  Future<void> push(WidgetTester tester, String location) async {
    router.push(location);
    await tester.pumpAndSettle();
  }
}

/// Botão pelo texto, qualquer que seja a variante (com ou sem ícone).
Finder buttonWithText<T extends ButtonStyleButton>(String text) =>
    find.ancestor(of: find.text(text), matching: find.bySubtype<T>());

/// Se o botão com este texto aceita toque.
bool isEnabled<T extends ButtonStyleButton>(WidgetTester tester, String text) =>
    tester.widget<T>(buttonWithText<T>(text)).onPressed != null;
