import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/pix_key_type.dart';
import 'package:voleiin/features/auth/domain/terms.dart';
import 'package:voleiin/features/auth/presentation/confirm_email_screen.dart';
import 'package:voleiin/features/auth/presentation/forgot_password_screen.dart';
import 'package:voleiin/features/auth/presentation/login_screen.dart';
import 'package:voleiin/features/auth/presentation/pending_email_provider.dart';
import 'package:voleiin/features/auth/presentation/profile_edit_screen.dart';
import 'package:voleiin/features/auth/presentation/profile_email_screen.dart';
import 'package:voleiin/features/auth/presentation/profile_password_screen.dart';
import 'package:voleiin/features/auth/presentation/profile_pix_screen.dart';
import 'package:voleiin/features/auth/presentation/profile_screen.dart';
import 'package:voleiin/features/auth/presentation/signup_screen.dart';
import 'package:voleiin/features/auth/presentation/terms_document_screen.dart';
import 'package:voleiin/features/auth/presentation/terms_screen.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/test_router.dart';

/// Cenário S16 de docs/testes-referencia.md, seção 10.4 (RNF05): todas as telas
/// da seção 5 do docs/ui/telas.md com a fonte do sistema em 150%, sem overflow.
void main() {
  setUpAll(registerFakes);

  final screens = <String, Widget Function(GoRouterState)>{
    Routes.login: (_) => const LoginScreen(),
    Routes.signup: (_) => const SignupScreen(),
    Routes.confirmEmail: (_) => const ConfirmEmailScreen(),
    Routes.forgotPassword: (_) => const ForgotPasswordScreen(),
    Routes.terms: (_) => const TermsScreen(),
    Routes.termsDocument: (s) =>
        TermsDocumentScreen(document: s.pathParameters['document'] ?? ''),
    Routes.profile: (_) => const ProfileScreen(),
    Routes.profileEdit: (_) => const ProfileEditScreen(),
    Routes.profilePix: (_) => const ProfilePixScreen(),
    Routes.profileEmail: (_) => const ProfileEmailScreen(),
    Routes.profilePassword: (_) => const ProfilePasswordScreen(),
  };

  final locations = {
    Routes.login: Routes.loginPath,
    Routes.signup: Routes.signupPath,
    Routes.confirmEmail: Routes.confirmEmailPath,
    Routes.forgotPassword: Routes.forgotPasswordPath,
    Routes.terms: Routes.termsPath,
    Routes.termsDocument: '/terms/privacy_policy',
    Routes.profile: Routes.profilePath,
    Routes.profileEdit: Routes.profileEditPath,
    Routes.profilePix: Routes.profilePixPath,
    Routes.profileEmail: Routes.profileEmailPath,
    Routes.profilePassword: Routes.profilePasswordPath,
  };

  for (final entry in locations.entries) {
    testWidgets('S16: ${entry.key} com a fonte em 150% não estoura', (
      tester,
    ) async {
      final auth = MockAuthRepository();
      when(() => auth.currentUserId).thenReturn(anaId);
      when(() => auth.currentEmail)
          .thenReturn('ana.souza.do.volei@exemplo.com');
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
      final terms = MockTermsRepository();
      when(() => terms.fetchStatus()).thenAnswer(
        (_) async => TermsStatus.compare(
          current: const [termsOfUse11, privacy10],
          accepted: const [termsOfUse10],
        ),
      );
      final profile = MockProfileRepository();
      when(() => profile.fetchOwn()).thenAnswer(
        (_) async => ownProfile(
          name: 'Ana Beatriz Souza de Albuquerque',
          phone: '+5586999991234',
          phoneVisible: true,
          pixKeyType: PixKeyType.cnpj,
          pixKey: '11222333000181',
        ),
      );

      await pumpRouterApp(
        tester,
        initialLocation: entry.value,
        textScale: 1.5,
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          termsRepositoryProvider.overrideWithValue(terms),
          profileRepositoryProvider.overrideWithValue(profile),
          photoPickerProvider.overrideWithValue(MockPhotoPicker()),
        ],
        setUp: (container) => container
            .read(pendingEmailProvider.notifier)
            .set('ana.souza.do.volei@exemplo.com'),
        screens: screens,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(stubText(entry.key)), findsNothing);
    });
  }
}
