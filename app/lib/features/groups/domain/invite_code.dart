/// Tamanho do código de convite: 12 caracteres base62 (docs/modelo-dados.md,
/// 4.2; RN11).
const inviteCodeLength = 12;

final _base62 = RegExp(r'^[0-9A-Za-z]{12}$');
final _spaces = RegExp(r'\s');

/// O código digitado como ele vai ao servidor (docs/ui/telas.md, 6.3): sem
/// nenhum espaço, inclusive os do meio, e na mesma caixa, porque o código
/// diferencia maiúsculas de minúsculas. Nulo se não sobrarem 12 letras ou
/// números (U08). É a regra da constraint do banco, só para o aviso no campo.
String? normalizeInviteCode(String typed) {
  final code = typed.replaceAll(_spaces, '');
  return _base62.hasMatch(code) ? code : null;
}
