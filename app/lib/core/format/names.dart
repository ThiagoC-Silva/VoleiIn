/// Ordem alfabética de exibição (docs/ui/telas.md, 6.1, 6.6 e 7.2), sem
/// diferenciar maiúsculas e acentos: "Areia" vem antes de "Vôlei", e "Ângela"
/// junto das outras com "A". Usada pelas features de grupos e de jogos.
int compareNames(String a, String b) {
  final byFolded = _fold(a).compareTo(_fold(b));
  return byFolded != 0 ? byFolded : a.compareTo(b);
}

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

String _fold(String text) =>
    text.toLowerCase().split('').map((char) => _accents[char] ?? char).join();
