import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/game_models.dart';
import 'game_badges.dart';

/// Card de jogo (docs/ui/design-system.md, 7.12; docs/ui/telas.md, 7.1;
/// games.png): o bloco da data, o grupo ou "Avulso", o local, as vagas, a
/// pílula do status, os selos de tempo e da pessoa e a barra de ocupação. Para
/// o TalkBack, o card inteiro lê o `gameCardLabel` (S60).
class GameCard extends ConsumerWidget {
  const GameCard({required this.game, required this.onTap, super.key});

  final GameSummary game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final now = ref.watch(clockProvider)();
    final group = game.groupName ?? l10n.gameStandalone;
    final timeBadge = gameTimeBadge(
      context,
      status: game.status,
      startsAt: game.startsAt,
      endsAt: game.endsAt,
      now: now,
    );
    final situation = gameSituationBadge(
      context,
      myStatus: game.myStatus,
      waitlistPosition: game.myWaitlistPosition,
    );
    final full = game.occupiedSlots >= game.slotLimit;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.gameCardLabel(
        group,
        formatShortDate(game.startsAt),
        formatTime(game.startsAt),
        game.locationName,
        gameStatusLabel(l10n, game.status),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateBlock(startsAt: game.startsAt),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // O grupo à esquerda e o status à direita; sem
                          // espaço, o status desce para a linha de baixo.
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    game.groupName == null
                                        ? Symbols.person
                                        : Symbols.groups,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      group,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              GameStatusPill(status: game.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            game.locationName,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                children: [
                                  Text(
                                    l10n.gameSlotsCount(
                                      '${game.occupiedSlots}',
                                      '${game.slotLimit}',
                                    ),
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(fontSize: 19),
                                  ),
                                  Text(
                                    l10n.gameSlotsUnit,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              ?timeBadge,
                              ?situation,
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OccupancyBar(
                  occupied: game.occupiedSlots,
                  limit: game.slotLimit,
                  color: game.status == GameStatus.cancelled
                      ? theme.colorScheme.onSurfaceVariant
                      : full
                      ? colors.wait
                      : colors.game,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloco da data (design-system.md, 7.12): dia da semana, dia e hora.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.startsAt});

  final DateTime startsAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = theme.textTheme.displaySmall;
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            formatWeekday(startsAt),
            style: number?.copyWith(
              fontSize: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDayOfMonth(startsAt),
            style: number?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 4),
          Text(
            formatTime(startsAt),
            style: number?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de ocupação de 6 (design-system.md, 7.11).
class OccupancyBar extends StatelessWidget {
  const OccupancyBar({
    required this.occupied,
    required this.limit,
    required this.color,
    super.key,
  });

  final int occupied;
  final int limit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = limit <= 0 ? 0.0 : (occupied / limit).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            FractionallySizedBox(
              widthFactor: fraction,
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
