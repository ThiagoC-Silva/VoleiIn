import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/badge.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';
import 'split_text.dart';

// Pílulas e selos do jogo (docs/ui/design-system.md, seção 4; docs/ui/telas.md,
// seção 7). O status sempre tem texto, nunca só a cor.

String gameStatusLabel(AppLocalizations l10n, GameStatus status) =>
    switch (status) {
      GameStatus.open => l10n.gameStatusOpen,
      GameStatus.confirmed => l10n.gameStatusConfirmed,
      GameStatus.cancelled => l10n.gameStatusCancelled,
      GameStatus.completed => l10n.gameStatusCompleted,
    };

/// Pílula do status: Aberto em `game`, Confirmado em `wait`, Concluído em
/// `onSurface`, todas com texto navy; Cancelado é o selo `bad`. Com
/// [outlined], a pílula fica só com o contorno navy, sobre o topo colorido do
/// detalhe (game.png).
class GameStatusPill extends StatelessWidget {
  const GameStatusPill({
    required this.status,
    this.outlined = false,
    super.key,
  });

  final GameStatus status;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final label = gameStatusLabel(l10n, status);
    if (status == GameStatus.cancelled) {
      return VoleiBadge(label: label, tone: colors.bad, dot: true);
    }
    final background = switch (status) {
      GameStatus.open => colors.game,
      GameStatus.confirmed => colors.wait,
      _ => theme.colorScheme.onSurface,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? null : background,
        borderRadius: BorderRadius.circular(999),
        border: outlined ? Border.all(color: colors.onBlock, width: 1.5) : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onBlock,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Selo de tempo, pelo relógio do aparelho e só para mostrar: `info` "Em
/// andamento" entre o início e o fim, e "Aguardando conclusão" depois do fim,
/// só em jogos Abertos e Confirmados (telas.md, seção 7). Nulo nos outros
/// casos.
Widget? gameTimeBadge(
  BuildContext context, {
  required GameStatus status,
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  if (!status.isActive || now.isBefore(startsAt)) return null;
  final l10n = AppLocalizations.of(context);
  return VoleiBadge(
    label: now.isBefore(endsAt)
        ? l10n.gameInProgress
        : l10n.gameAwaitingCompletion,
    tone: VoleiColors.of(context).info,
    dot: true,
  );
}

/// Selo da situação da pessoa no jogo (telas.md, seção 7): "Na lista", "Saiu
/// após o início" ou "1º na espera". Nulo sem nenhuma das três.
Widget? gameSituationBadge(
  BuildContext context, {
  ParticipantStatus? myStatus,
  int? waitlistPosition,
}) {
  final l10n = AppLocalizations.of(context);
  final colors = VoleiColors.of(context);
  if (myStatus == ParticipantStatus.active) {
    return VoleiBadge(label: l10n.gameOnList, tone: colors.ok, dot: true);
  }
  if (myStatus == ParticipantStatus.leftAfterStart) {
    return VoleiBadge(
      label: l10n.gameLeftAfterStartBadge,
      tone: colors.bad,
      dot: true,
    );
  }
  if (waitlistPosition != null) {
    return VoleiBadge(
      label: l10n.gameWaitlistPosition('$waitlistPosition'),
      tone: colors.waiting,
      dot: true,
    );
  }
  return null;
}

/// Selo do status do valor a pagar (design-system.md, seção 4): Pendente
/// `warn`, Em análise `info`, Pago `ok`, Isento `neutral`.
class ChargeStatusBadge extends StatelessWidget {
  const ChargeStatusBadge({required this.status, super.key});

  final ChargeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = VoleiColors.of(context);
    return VoleiBadge(
      label: chargeStatusLabel(AppLocalizations.of(context), status),
      tone: switch (status) {
        ChargeStatus.pending => colors.warn,
        ChargeStatus.underReview => colors.info,
        ChargeStatus.paid => colors.ok,
        ChargeStatus.waived => colors.neutral,
      },
      dot: status != ChargeStatus.waived,
    );
  }
}
