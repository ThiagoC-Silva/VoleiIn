import 'package:flutter/material.dart';

import '../../../core/format/date_time.dart';

// Instantes do formulário do jogo (docs/ui/telas.md, 7.2; U10). A pessoa
// escolhe em `America/Fortaleza`, e o app envia em UTC
// (docs/arquitetura-app.md, seção 8).

/// A data e a hora escolhidas, em UTC: o início e o prazo.
DateTime gameDateTimeUtc(DateTime date, TimeOfDay time) => fortalezaToUtc(
  DateTime(date.year, date.month, date.day, time.hour, time.minute),
);

/// O fim, que é só a hora: mais cedo que o início, termina no dia seguinte.
/// Nulo quando o fim é igual ao início (`gameEndSameAsStart`).
({DateTime endsAt, bool nextDay})? gameEndUtc(
  DateTime date,
  TimeOfDay start,
  TimeOfDay end,
) {
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;
  if (endMinutes == startMinutes) return null;
  final nextDay = endMinutes < startMinutes;
  final day = DateTime(date.year, date.month, date.day + (nextDay ? 1 : 0));
  return (endsAt: gameDateTimeUtc(day, end), nextDay: nextDay);
}
