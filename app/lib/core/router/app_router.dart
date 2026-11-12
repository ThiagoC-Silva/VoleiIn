import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/games/presentation/games_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/splits/presentation/charges_screen.dart';
import '../../shared/widgets/app_shell.dart';
import 'routes.dart';

/// Roteador do app (docs/arquitetura-app.md, seção 9).
///
/// Redirecionamentos da fatia 1: sem sessão vai para o login; com sessão, quem
/// abre o login vai para a aba Jogos. A fatia 2 acrescenta, nesta ordem, o
/// e-mail não confirmado e o aceite dos termos.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefreshNotifier(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.gamesPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.hasSession;
      final atLogin = state.matchedLocation == Routes.loginPath;

      if (!loggedIn) return atLogin ? null : Routes.loginPath;
      if (atLogin) return Routes.gamesPath;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.loginPath,
        name: Routes.login,
        builder: (context, state) => const LoginScreen(),
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
/// token. Falta de conexão não invalida a sessão (RNF07).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
