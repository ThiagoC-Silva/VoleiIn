/// A conta tem acesso por e-mail e senha quando uma das identidades do Supabase
/// Auth é a de `email` (docs/ui/telas.md, 5.7; cenário U07). Quem entrou só pelo
/// Google não tem; quem vinculou as duas formas (RF108) tem.
bool hasEmailPassword(Iterable<String> providers) =>
    providers.contains('email');
