import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/confirm_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_edit_screen.dart';
import '../../features/auth/presentation/profile_email_screen.dart';
import '../../features/auth/presentation/profile_password_screen.dart';
import '../../features/auth/presentation/profile_pix_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/terms_document_screen.dart';
import '../../features/auth/presentation/terms_screen.dart';
import '../../features/games/presentation/games_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/splits/presentation/charges_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Roteador do app (docs/arquitetura-app.md, seção 9; docs/ui/telas.md, 3.1).
///
/// Redirecionamentos, nesta ordem:
/// 1. sem sessão → `/login`, salvo nas rotas de acesso; a `/confirm-email`
///    precisa do e-mail em memória;
/// 2. com sessão, no meio da recuperação de senha → fica na tela (research R2);
/// 3. com sessão e sem o aceite da versão vigente dos termos → `/terms`,
///    inclusive enquanto a conferência carrega ou falha (research R3);
/// 4. com sessão, numa rota de acesso ou nos termos → `/games`;
/// 5. sem acesso por e-mail e senha, na troca de e-mail ou senha → `/profile`.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _RefreshNotifier(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  // O roteador não é recriado: estes estados só pedem uma nova conferência.
  ref.listen(termsStatusProvider, (_, _) => refresh.notify());
  ref.listen(accessDraftProvider, (_, _) => refresh.notify());
  ref.listen(passwordRecoveryInProgressProvider, (_, _) => refresh.notify());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.gamesPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final atAccess = Routes.accessPaths.contains(location);
      final atTerms =
          location == Routes.termsPath ||
          location.startsWith('${Routes.termsPath}/');

      if (!auth.hasSession) {
        if (location == Routes.confirmEmailPath &&
            ref.read(accessDraftProvider) == null) {
          return Routes.loginPath;
        }
        return atAccess ? null : Routes.loginPath;
      }

      if (location == Routes.forgotPasswordPath &&
          ref.read(passwordRecoveryInProgressProvider)) {
        return null;
      }

      final upToDate = ref.read(termsStatusProvider).value?.upToDate ?? false;
      if (!upToDate) return atTerms ? null : Routes.termsPath;

      if (atAccess || atTerms) return Routes.gamesPath;

      if (Routes.emailAccessPaths.contains(location) && !auth.hasEmailAccess) {
        return Routes.profilePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.loginPath,
        name: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signupPath,
        name: Routes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: Routes.confirmEmailPath,
        name: Routes.confirmEmail,
        builder: (context, state) => const ConfirmEmailScreen(),
      ),
      GoRoute(
        path: Routes.forgotPasswordPath,
        name: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.termsPath,
        name: Routes.terms,
        builder: (context, state) => const TermsScreen(),
        routes: [
          GoRoute(
            path: Routes.termsDocumentPath,
            name: Routes.termsDocument,
            builder: (context, state) => TermsDocumentScreen(
              document: state.pathParameters['document']!,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.gamesPath,
                name: Routes.games,
                builder: (context, state) => const GamesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.groupsPath,
                name: Routes.groups,
                builder: (context, state) => const GroupsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chargesPath,
                name: Routes.charges,
                builder: (context, state) => const ChargesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profilePath,
                name: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
                // Telas fora das abas: cobrem a barra inferior (telas.md, 3.2).
                routes: [
                  GoRoute(
                    path: Routes.profileEditPath,
                    name: Routes.profileEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfileEditScreen(),
                  ),
                  GoRoute(
                    path: Routes.profilePixPath,
                    name: Routes.profilePix,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfilePixScreen(),
                  ),
                  GoRoute(
                    path: Routes.profileEmailPath,
                    name: Routes.profileEmail,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfileEmailScreen(),
                  ),
                  GoRoute(
                    path: Routes.profilePasswordPath,
                    name: Routes.profilePassword,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfilePasswordScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Pede ao `go_router` uma nova conferência a cada mudança de sessão,
/// inclusive a invalidação do token, e a cada estado que entra nos
/// redirecionamentos. Falta de conexão não invalida a sessão (RNF07).
class _RefreshNotifier extends ChangeNotifier {
  _RefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notify());
  }

  late final StreamSubscription<dynamic> _subscription;

  void notify() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
