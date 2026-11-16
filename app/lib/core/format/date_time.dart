import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Data e hora sempre em `America/Fortaleza` (RN01). O fuso e o relógio do
/// aparelho não entram na conta (docs/arquitetura-app.md, seção 8).
const String fortalezaName = 'America/Fortaleza';

/// Dias da semana abreviados, em minúsculas e sem ponto (docs/copy.md, seção 3).
/// A lista é fixa no código: o `intl` põe ponto depois da abreviação.
const List<String> weekdayAbbreviations = [
  'seg', // DateTime.monday == 1
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
  'dom',
];

tz.Location? _fortalezaLocation;

/// Carrega o banco de fusos. Chamada no `main`, antes de `runApp`.
void initTimeZones() {
  tz_data.initializeTimeZones();
  _fortalezaLocation = tz.getLocation(fortalezaName);
}

tz.Location get _fortaleza {
  final location = _fortalezaLocation;
  if (location != null) return location;
  // Conveniência para os testes unitários, que não passam pelo `main`.
  initTimeZones();
  return _fortalezaLocation!;
}

/// `2026-11-09T23:00:00Z` vira `09/11/2026`.
String formatDate(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _fortaleza);
  return '${_pad(local.day)}/${_pad(local.month)}/${local.year}';
}

/// `2026-11-09T23:00:00Z` vira `20:00`, em 24 horas.
String formatTime(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _fortaleza);
  return '${_pad(local.hour)}:${_pad(local.minute)}';
}

/// `2026-10-22T23:00:00Z` vira `qui, 22/10`.
String formatShortDate(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _fortaleza);
  final weekday = weekdayAbbreviations[local.weekday - 1];
  return '$weekday, ${_pad(local.day)}/${_pad(local.month)}';
}

/// `2026-11-22T00:00:00Z` (sábado, 21:00 em Fortaleza) vira `sáb`. O bloco de
/// data do card de jogo (docs/ui/design-system.md, 7.12).
String formatWeekday(DateTime instant) {
  final local = tz.TZDateTime.from(instant, _fortaleza);
  return weekdayAbbreviations[local.weekday - 1];
}

/// O dia do mês, com dois dígitos: `07`, `21`.
String formatDayOfMonth(DateTime instant) =>
    _pad(tz.TZDateTime.from(instant, _fortaleza).day);

/// O instante em `America/Fortaleza`, para preencher os campos de data e hora
/// de um formulário com um valor gravado (Editar jogo).
DateTime fortalezaLocal(DateTime instant) =>
    tz.TZDateTime.from(instant, _fortaleza);

/// Uma data escolhida no seletor, ainda sem fuso, em `dd/mm/aaaa`.
String formatPickedDate(DateTime date) =>
    '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

/// Uma hora escolhida no seletor, em `HH:mm`.
String formatPickedTime(int hour, int minute) =>
    '${_pad(hour)}:${_pad(minute)}';

/// Converte a data e a hora escolhidas na tela, que são de `America/Fortaleza`,
/// no instante UTC enviado ao servidor (docs/contratos-api.md, seção 1).
///
/// Só ano, mês, dia, hora e minuto entram: os seletores não têm segundos.
/// Devolve um `DateTime` UTC comum, e não um `TZDateTime`, que não é igual
/// a um `DateTime` do mesmo instante no `==`.
DateTime fortalezaToUtc(DateTime chosen) {
  final local = tz.TZDateTime(
    _fortaleza,
    chosen.year,
    chosen.month,
    chosen.day,
    chosen.hour,
    chosen.minute,
  );
  return DateTime.fromMicrosecondsSinceEpoch(
    local.microsecondsSinceEpoch,
    isUtc: true,
  );
}

String _pad(int value) => value.toString().padLeft(2, '0');
