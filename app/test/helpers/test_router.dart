import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voleiin/core/router/routes.dart';
import 'package:voleiin/core/theme/app_theme.dart';
import 'package:voleiin/l10n/app_localizations.dart';

/// Caminho e nome de todas as rotas, para o roteador dos testes de tela.
const allRoutes = <String, String>{
  Routes.login: Routes.loginPath,
  Routes.signup: Routes.signupPath,
  Routes.confirmEmail: Routes.confirmEmailPath,
  Routes.forgotPassword: Routes.forgotPasswordPath,
  Routes.terms: Routes.termsPath,
  Routes.termsDocument: Routes.termsDocumentPath,
  Routes.games: Routes.gamesPath,
  Routes.groups: Routes.groupsPath,
  Routes.charges: Routes.chargesPath,
  Routes.profile: Routes.profilePath,
  Routes.profileEdit: Routes.profileEditPath,
  Routes.profilePix: Routes.profilePixPath,
  Routes.profileEmail: Routes.profileEmailPath,
  Routes.profilePassword: Routes.profilePasswordPath,
};

/// Texto que a rota de mentira mostra, para o teste saber onde está.
String stubText(String routeName) => 'stub:$routeName';

/// Monta o app com um roteador simples: as telas em [screens] são reais, e as
/// outras rotas mostram só [stubText]. Devolve o container, para o teste
/// preparar ou ler providers.
Future<ProviderContainer> pumpRouterApp(
  WidgetTester tester, {
  required String initialLocation,
  required Map<String, Widget Function(GoRouterState state)> screens,
  List<Override> overrides = const [],
  void Function(ProviderContainer container)? setUp,
  double textScale = 1.0,
}) async {
  // Celular comum (412 x 915 dp), como nos PNGs de referência.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  setUp?.call(container);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      for (final entry in allRoutes.entries)
        GoRoute(
          path: entry.value,
          name: entry.key,
          builder: (context, state) =>
              screens[entry.key]?.call(state) ??
              Scaffold(body: Text(stubText(entry.key))),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Rola até o widget e toca nele: com a fonte grande ou o teclado, o botão
/// pode ficar fora da tela.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
