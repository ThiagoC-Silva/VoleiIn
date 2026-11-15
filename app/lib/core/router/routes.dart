/// Rotas do app (docs/ui/telas.md, seção 2.2).
///
/// O nome da rota é o caminho em `camelCase`, sem os parâmetros. A navegação é
/// sempre por nome (docs/arquitetura-app.md, seção 9).
class Routes {
  const Routes._();

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String signup = 'signup';
  static const String signupPath = '/signup';

  static const String confirmEmail = 'confirmEmail';
  static const String confirmEmailPath = '/confirm-email';

  static const String forgotPassword = 'forgotPassword';
  static const String forgotPasswordPath = '/forgot-password';

  static const String terms = 'terms';
  static const String termsPath = '/terms';

  /// `/terms/:document`, com o valor do enum `legal_document`.
  static const String termsDocument = 'termsDocument';
  static const String termsDocumentPath = ':document';

  static const String games = 'games';
  static const String gamesPath = '/games';

  static const String groups = 'groups';
  static const String groupsPath = '/groups';

  // Telas de grupo (docs/ui/telas.md, seção 6). Os caminhos abaixo são
  // relativos a `/groups`; `new` e `join` vêm antes de `:groupId`.
  static const String groupsNew = 'groupsNew';
  static const String groupsNewPath = 'new';

  static const String groupsJoin = 'groupsJoin';
  static const String groupsJoinPath = 'join';

  static const String group = 'group';
  static const String groupPath = ':groupId';

  static const String groupEdit = 'groupEdit';
  static const String groupEditPath = 'edit';

  static const String groupMembers = 'groupMembers';
  static const String groupMembersPath = 'members';

  static const String groupRequests = 'groupRequests';
  static const String groupRequestsPath = 'requests';

  /// `/people/:userId`: perfil de outra pessoa, na aba de origem (6.9).
  static const String person = 'person';
  static const String personPath = '/people/:userId';

  static const String charges = 'charges';
  static const String chargesPath = '/charges';

  static const String profile = 'profile';
  static const String profilePath = '/profile';

  static const String profileEdit = 'profileEdit';
  static const String profileEditPath = 'edit';

  static const String profilePix = 'profilePix';
  static const String profilePixPath = 'pix';

  static const String profileEmail = 'profileEmail';
  static const String profileEmailPath = 'email';

  static const String profilePassword = 'profilePassword';
  static const String profilePasswordPath = 'password';

  /// Rotas de acesso: abrem sem sessão (docs/ui/telas.md, 3.1).
  static const Set<String> accessPaths = {
    loginPath,
    signupPath,
    confirmEmailPath,
    forgotPasswordPath,
  };

  /// Só para quem tem acesso por e-mail e senha (docs/ui/telas.md, 5.7).
  static const Set<String> emailAccessPaths = {
    '$profilePath/$profileEmailPath',
    '$profilePath/$profilePasswordPath',
  };
}
