/// Rotas do app (docs/ui/telas.md, seção 2.2).
///
/// O nome da rota é o caminho em `camelCase`, sem os parâmetros. A navegação é
/// sempre por nome (docs/arquitetura-app.md, seção 9).
class Routes {
  const Routes._();

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String games = 'games';
  static const String gamesPath = '/games';

  static const String groups = 'groups';
  static const String groupsPath = '/groups';

  static const String charges = 'charges';
  static const String chargesPath = '/charges';

  static const String profile = 'profile';
  static const String profilePath = '/profile';
}
