import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Os seletores nativos de data e hora (docs/ui/design-system.md, 7.2),
/// trocáveis por dublê nos testes, como o `PhotoPicker`.
class DateTimePicker {
  const DateTimePicker();

  /// Nulo se a pessoa fechou o seletor.
  Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = initial != null && initial.isBefore(today) ? initial : today;
    return showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: first,
      lastDate: DateTime(today.year + 2, 12, 31),
    );
  }

  /// Nulo se a pessoa fechou o seletor. Sempre em 24 horas (docs/copy.md,
  /// seção 3).
  Future<TimeOfDay?> pickTime(BuildContext context, {TimeOfDay? initial}) {
    return showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 20, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }
}

final dateTimePickerProvider = Provider<DateTimePicker>(
  (ref) => const DateTimePicker(),
);
