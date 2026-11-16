import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/date_time_picker.dart';
import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/format/money_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/picker_field.dart';
import '../../../shared/widgets/slot_counter.dart';
import '../domain/game_models.dart';
import 'game_form_values.dart';

/// Os campos do jogo, comuns à criação e à edição (docs/ui/telas.md, 7.2,
/// itens 3 a 9, e 7.4). Guarda o que foi digitado e escolhido, e confere tudo
/// antes de chamar o servidor, que confere de novo (RN23, RN33).
class GameFormData {
  GameFormData();

  /// Os dados gravados, em `America/Fortaleza`, para a edição.
  GameFormData.fromGame(GameDetail game) {
    final start = fortalezaLocal(game.startsAt);
    final end = fortalezaLocal(game.endsAt);
    final deadline = fortalezaLocal(game.cancellationDeadline);
    location.text = game.locationName;
    maps.text = game.mapsUrl ?? '';
    date = DateTime(start.year, start.month, start.day);
    this.start = TimeOfDay(hour: start.hour, minute: start.minute);
    this.end = TimeOfDay(hour: end.hour, minute: end.minute);
    deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    deadlineTime = TimeOfDay(hour: deadline.hour, minute: deadline.minute);
    total.text = formatCentsInput(game.totalCents);
    slots.text = '${game.slotLimit}';
  }

  final location = TextEditingController();
  final maps = TextEditingController();
  final total = TextEditingController();
  final slots = TextEditingController();
  DateTime? date;
  TimeOfDay? start;
  TimeOfDay? end;
  DateTime? deadlineDate;
  TimeOfDay? deadlineTime;

  void dispose() {
    location.dispose();
    maps.dispose();
    total.dispose();
    slots.dispose();
  }

  static const maxLocationLength = 120;

  String get _location => location.text.trim();
  String? get _maps => maps.text.trim().isEmpty ? null : maps.text.trim();
  int? get totalCents => parseMoneyInput(total.text);
  int? get slotLimit => int.tryParse(slots.text);

  DateTime? get startsAt =>
      date == null || start == null ? null : gameDateTimeUtc(date!, start!);

  ({DateTime endsAt, bool nextDay})? get _end =>
      date == null || start == null || end == null
      ? null
      : gameEndUtc(date!, start!, end!);

  DateTime? get cancellationDeadline =>
      deadlineDate == null || deadlineTime == null
      ? null
      : gameDateTimeUtc(deadlineDate!, deadlineTime!);

  String? locationError(AppLocalizations l10n) {
    if (_location.isEmpty) return l10n.gameLocationRequired;
    if (_location.length > maxLocationLength) return l10n.gameLocationTooLong;
    return null;
  }

  String? mapsError(AppLocalizations l10n) =>
      _maps != null && !_maps!.startsWith('https://')
      ? l10n.gameMapsInvalid
      : null;

  String? dateError(AppLocalizations l10n) =>
      date == null ? l10n.gameDateRequired : null;

  /// O início no passado, pelo relógio do aparelho, só avisa: o servidor
  /// confere de novo (`START_IN_PAST`, telas.md, 7.2).
  String? startError(AppLocalizations l10n, DateTime now) {
    if (start == null) return l10n.gameTimeRequired;
    final startsAt = this.startsAt;
    if (startsAt != null && !startsAt.isAfter(now)) return l10n.gameStartInPast;
    return null;
  }

  String? endError(AppLocalizations l10n) {
    if (end == null) return l10n.gameTimeRequired;
    if (start != null && end == start) return l10n.gameEndSameAsStart;
    return null;
  }

  /// "Termina dom, 23/11." quando o fim cai no dia seguinte.
  String? endHint(AppLocalizations l10n) {
    final end = _end;
    if (end == null || !end.nextDay) return null;
    return l10n.gameEndsNextDay(formatShortDate(end.endsAt));
  }

  String? deadlineDateError(AppLocalizations l10n) =>
      deadlineDate == null ? l10n.gameDateRequired : null;

  String? deadlineTimeError(AppLocalizations l10n) {
    if (deadlineTime == null) return l10n.gameTimeRequired;
    final deadline = cancellationDeadline;
    final startsAt = this.startsAt;
    if (deadline != null && startsAt != null && deadline.isAfter(startsAt)) {
      return l10n.gameDeadlineAfterStart;
    }
    return null;
  }

  String? totalError(AppLocalizations l10n) {
    final cents = totalCents;
    return cents == null || cents < 1 ? l10n.gameTotalRequired : null;
  }

  String? slotsError(AppLocalizations l10n) {
    final limit = slotLimit;
    return limit == null || limit < 1 ? l10n.gameSlotLimitRequired : null;
  }

  /// Se os campos que não são de texto estão certos (os de texto passam pelo
  /// `Form.validate()`).
  bool pickersValid(AppLocalizations l10n, DateTime now) =>
      dateError(l10n) == null &&
      startError(l10n, now) == null &&
      endError(l10n) == null &&
      deadlineDateError(l10n) == null &&
      deadlineTimeError(l10n) == null;

  /// Os dados para o servidor, depois da validação. O local sem os espaços
  /// das pontas e o link nulo quando vazio (telas.md, 7.2).
  GameInput toInput() => GameInput(
    locationName: _location,
    mapsUrl: _maps,
    cancellationDeadline: cancellationDeadline!,
    startsAt: startsAt!,
    endsAt: _end!.endsAt,
    totalCents: totalCents!,
    slotLimit: slotLimit!,
  );
}

/// Os campos 3 a 9 da criação (telas.md, 7.2), com o aviso da estimativa.
/// [showErrors] liga os erros dos campos de data e hora, que não são
/// `TextFormField`, depois da primeira tentativa de salvar.
class GameFormFields extends ConsumerWidget {
  const GameFormFields({
    required this.data,
    required this.showErrors,
    required this.now,
    required this.onChanged,
    this.enabled = true,
    this.minSlots = 1,
    this.slotsHelper,
    super.key,
  });

  final GameFormData data;
  final bool showErrors;
  final DateTime now;
  final VoidCallback onChanged;
  final bool enabled;

  /// O menor valor do botão −: as vagas ocupadas, na edição (RN59).
  final int minSlots;

  /// "8 pessoas na lista", na edição.
  final String? slotsHelper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final pickers = ref.read(dateTimePickerProvider);

    Future<void> pickDate(
      DateTime? current,
      void Function(DateTime) set,
    ) async {
      final picked = await pickers.pickDate(context, initial: current);
      if (picked != null) {
        set(picked);
        onChanged();
      }
    }

    Future<void> pickTime(
      TimeOfDay? current,
      void Function(TimeOfDay) set,
    ) async {
      final picked = await pickers.pickTime(context, initial: current);
      if (picked != null) {
        set(picked);
        onChanged();
      }
    }

    String? time(TimeOfDay? value) =>
        value == null ? null : formatPickedTime(value.hour, value.minute);
    String? day(DateTime? value) =>
        value == null ? null : formatPickedDate(value);

    final total = data.totalCents;
    final limit = data.slotLimit;
    const gap = SizedBox(height: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          key: const Key('gameLocationField'),
          label: l10n.gameLocationLabel,
          controller: data.location,
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (_) => data.locationError(l10n),
        ),
        gap,
        LabeledField(
          key: const Key('gameMapsField'),
          label: l10n.gameMapsLabel,
          controller: data.maps,
          enabled: enabled,
          helperText: l10n.gameMapsHint,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          validator: (_) => data.mapsError(l10n),
        ),
        gap,
        PickerField(
          key: const Key('gameDateField'),
          label: l10n.gameDateLabel,
          semanticLabel: l10n.gameDateLabel,
          value: day(data.date),
          icon: Symbols.calendar_today,
          enabled: enabled,
          errorText: showErrors ? data.dateError(l10n) : null,
          onTap: () => pickDate(data.date, (value) => data.date = value),
        ),
        gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PickerField(
                key: const Key('gameStartField'),
                label: l10n.gameStartLabel,
                semanticLabel: l10n.gameStartLabel,
                value: time(data.start),
                icon: Symbols.schedule,
                enabled: enabled,
                errorText: showErrors ? data.startError(l10n, now) : null,
                onTap: () =>
                    pickTime(data.start, (value) => data.start = value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PickerField(
                key: const Key('gameEndField'),
                label: l10n.gameEndLabel,
                semanticLabel: l10n.gameEndLabel,
                value: time(data.end),
                icon: Symbols.schedule,
                enabled: enabled,
                errorText: showErrors ? data.endError(l10n) : null,
                helperText: data.endHint(l10n),
                onTap: () => pickTime(data.end, (value) => data.end = value),
              ),
            ),
          ],
        ),
        gap,
        FieldLabel(l10n.gameDeadlineLabel),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PickerField(
                key: const Key('gameDeadlineDateField'),
                semanticLabel: l10n.gameDeadlineLabel,
                value: day(data.deadlineDate),
                icon: Symbols.calendar_today,
                enabled: enabled,
                errorText: showErrors ? data.deadlineDateError(l10n) : null,
                onTap: () => pickDate(
                  data.deadlineDate,
                  (value) => data.deadlineDate = value,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PickerField(
                key: const Key('gameDeadlineTimeField'),
                semanticLabel: l10n.gameDeadlineLabel,
                value: time(data.deadlineTime),
                icon: Symbols.schedule,
                enabled: enabled,
                errorText: showErrors ? data.deadlineTimeError(l10n) : null,
                onTap: () => pickTime(
                  data.deadlineTime,
                  (value) => data.deadlineTime = value,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.gameDeadlineHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        gap,
        LabeledField(
          key: const Key('gameTotalField'),
          label: l10n.gameTotalLabel,
          controller: data.total,
          enabled: enabled,
          prefixText: currencySymbol,
          keyboardType: TextInputType.number,
          inputFormatters: const [MoneyInputFormatter()],
          style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
          onChanged: (_) => onChanged(),
          validator: (_) => data.totalError(l10n),
        ),
        gap,
        SlotCounterField(
          key: const Key('gameSlotLimitField'),
          label: l10n.gameSlotLimitLabel,
          controller: data.slots,
          enabled: enabled,
          min: minSlots,
          decreaseLabel: l10n.gameSlotLimitDecrease,
          increaseLabel: l10n.gameSlotLimitIncrease,
          helperText: slotsHelper,
          onChanged: (_) => onChanged(),
          validator: (_) => data.slotsError(l10n),
        ),
        // A estimativa, só com o valor e o limite preenchidos (RN24).
        if (total != null && total > 0 && limit != null && limit > 0) ...[
          gap,
          InlineNotice(
            icon: Symbols.calculate,
            color: colors.split,
            title: l10n.gameEstimate(
              formatCents(estimatedShareCents(total, limit)),
            ),
            text: l10n.gameEstimateHint,
          ),
        ],
      ],
    );
  }
}
