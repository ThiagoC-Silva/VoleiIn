/// Quem tem acesso por e-mail e senha: a conta tem a identidade `email` no
/// Supabase Auth (docs/ui/telas.md, 5.7; U07). Quem entrou só pelo Google não
/// a tem e não vê Trocar e-mail nem Trocar senha.
bool hasEmailAccess(Iterable<String> identityProviders) =>
    identityProviders.contains('email');
