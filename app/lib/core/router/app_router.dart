import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/confirm_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_email_provider.dart';
import '../../features/auth/presentation/profile_edit_screen.dart';
import '../../features/auth/presentation/profile_email_screen.dart';
import '../../features/auth/presentation/profile_password_screen.dart';
import '../../features/auth/presentation/profile_pix_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/terms_document_screen.dart';
import '../../features/auth/presentation/terms_providers.dart';
import '../../features/auth/presentation/terms_screen.dart';
import '../../features/games/presentation/games_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/splits/presentation/charges_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

/// Roteador do app (docs/arquitetura-app.md, seção 9; docs/ui/telas.md, 3.1).
///
/// Redirecionamentos, nesta ordem:
/// 1. sem sessão → login, salvo nas rotas de acesso;
/// 2. com sessão numa rota de acesso → aba Jogos, salvo a recuperação de senha
///    em andamento (o código cria a sessão antes da senha nova, telas.md 5.4);
/// 3. termos não aceitos na versão vigente, ou a conferência ainda carregando
///    ou com erro → `/terms`, que mostra esses estados (RF105);
/// 4. Trocar e-mail e Trocar senha sem acesso por e-mail e senha → perfil.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _RouterRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);
  // A conferência dos termos muda de estado sem mexer na sessão.
  ref.listen(termsStatusProvider, (_, _) => refresh.notify());

  return GoRouter(
    initialLocation: Routes.gamesPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final atAccess = Routes.accessPaths.contains(location);

      if (!auth.hasSession) return atAccess ? null : Routes.loginPath;

      if (atAccess) {
        final recovering =
            location == Routes.forgotPasswordPath &&
            ref.read(recoveryInProgressProvider);
        return recovering ? null : Routes.gamesPath;
      }

      if (location.startsWith('${Routes.termsPath}/')) return null;

      final terms = ref.read(termsStatusProvider);
      final status = terms.isLoading || terms.hasError ? null : terms.value;
      if (status == null || !status.accepted) {
        return location == Routes.termsPath ? null : Routes.termsPath;
      }
      if (location == Routes.termsPath) return Routes.gamesPath;

      if ((location == Routes.profileEmailPath ||
              location == Routes.profilePasswordPath) &&
          !auth.hasEmailPassword) {
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
            path: ':document',
            name: Routes.termsDocument,
            builder: (context, state) => TermsDocumentScreen(
              document: state.pathParameters['document'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.profileEditPath,
        name: Routes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: Routes.profilePixPath,
        name: Routes.profilePix,
        builder: (context, state) => const ProfilePixScreen(),
      ),
      GoRoute(
        path: Routes.profileEmailPath,
        name: Routes.profileEmail,
        builder: (context, state) => const ProfileEmailScreen(),
      ),
      GoRoute(
        path: Routes.profilePasswordPath,
        name: Routes.profilePassword,
        builder: (context, state) => const ProfilePasswordScreen(),
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Avisa o `go_router` a cada mudança de sessão, inclusive a invalidação do
/// token, e a cada mudança da conferência dos termos. Falta de conexão não
/// invalida a sessão (RNF07).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void notify() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
