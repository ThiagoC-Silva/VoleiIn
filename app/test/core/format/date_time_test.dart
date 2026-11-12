import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/format/date_time.dart';

/// Cenários D09 a D14 de docs/testes-referencia.md, seção 9.3.
///
/// D15: os mesmos testes rodam com o processo em outro fuso
/// (`TZ=Asia/Tokyo flutter test`, no CI). O fuso do aparelho não entra na conta,
/// porque a conversão usa sempre America/Fortaleza (RN01).
void main() {
  setUpAll(initTimeZones);

  test('D09: 2026-11-09T23:00:00Z é 09/11/2026 às 20:00 em Fortaleza', () {
    final instant = DateTime.utc(2026, 11, 9, 23);
    expect(formatDate(instant), '09/11/2026');
    expect(formatTime(instant), '20:00');
  });

  test('D10: 2026-11-10T02:30:00Z ainda é dia 9 em Fortaleza', () {
    final instant = DateTime.utc(2026, 11, 10, 2, 30);
    expect(formatDate(instant), '09/11/2026');
    expect(formatTime(instant), '23:30');
  });

  test('D11: 2026-11-10T03:00:00Z vira 10/11/2026 00:00', () {
    final instant = DateTime.utc(2026, 11, 10, 3);
    expect(formatDate(instant), '10/11/2026');
    expect(formatTime(instant), '00:00');
  });

  test('D12: 2026-10-22T23:00:00Z vira qui, 22/10', () {
    expect(formatShortDate(DateTime.utc(2026, 10, 22, 23)), 'qui, 22/10');
  });

  test('D13: 2026-10-25T02:59:00Z vira sáb, 24/10', () {
    expect(formatShortDate(DateTime.utc(2026, 10, 25, 2, 59)), 'sáb, 24/10');
  });

  test('D14: 09/11/2026 às 20:00 na tela vira 2026-11-09T23:00:00.000Z', () {
    final chosen = DateTime(2026, 11, 9, 20);
    final sent = fortalezaToUtc(chosen);
    expect(sent.isUtc, isTrue);
    expect(sent.toIso8601String(), '2026-11-09T23:00:00.000Z');
  });
}
