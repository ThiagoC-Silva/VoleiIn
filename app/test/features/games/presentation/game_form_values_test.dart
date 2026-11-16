import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/date_time.dart';
import 'package:voleiin/features/games/presentation/game_form_values.dart';

import '../../../helpers/test_app.dart';

/// Cenário U10 de docs/testes-referencia.md, seção 12.6: os instantes do
/// formulário do jogo, escolhidos em `America/Fortaleza` e enviados em UTC
/// (docs/ui/telas.md, 7.2; docs/arquitetura-app.md, seção 8). O fim é só a
/// hora: um fim mais cedo que o início termina no dia seguinte.
void main() {
  // 28/11/2026 é um sábado.
  final date = DateTime(2026, 11, 28);

  test('U10: início 20:00 e fim 22:00', () {
    expect(
      gameDateTimeUtc(date, const TimeOfDay(hour: 20, minute: 0)),
      DateTime.utc(2026, 11, 28, 23),
    );
    final end = gameEndUtc(
      date,
      const TimeOfDay(hour: 20, minute: 0),
      const TimeOfDay(hour: 22, minute: 0),
    );
    expect(end, isNotNull);
    expect(end!.endsAt, DateTime.utc(2026, 11, 29, 1));
    expect(end.nextDay, isFalse);
  });

  test('U10: início 23:00 e fim 01:00 termina no dia seguinte', () {
    final end = gameEndUtc(
      date,
      const TimeOfDay(hour: 23, minute: 0),
      const TimeOfDay(hour: 1, minute: 0),
    );
    expect(end!.endsAt, DateTime.utc(2026, 11, 29, 4));
    expect(end.nextDay, isTrue);
    expect(
      l10nPt.gameEndsNextDay(formatShortDate(end.endsAt)),
      'Termina dom, 29/11.',
    );
  });

  test('U10: fim igual ao início é erro (gameEndSameAsStart)', () {
    expect(
      gameEndUtc(
        date,
        const TimeOfDay(hour: 20, minute: 0),
        const TimeOfDay(hour: 20, minute: 0),
      ),
      isNull,
    );
  });

  test('U10: prazo 28/11 18:00', () {
    expect(
      gameDateTimeUtc(date, const TimeOfDay(hour: 18, minute: 0)),
      DateTime.utc(2026, 11, 28, 21),
    );
  });
}
