import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/clock.dart';
import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/link_opener.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/badge.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/pix_key.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';
import 'game_badges.dart';
import 'game_controllers.dart';
import 'game_trio.dart';
import 'split_text.dart';
import 'games_providers.dart';

/// Detalhe do jogo (RF37, RF45 a RF47, RF49, RF55; docs/ui/telas.md, 7.3;
/// game.png, game-admin.png, game-confirmado.png, game-espera.png,
/// game-andamento.png e game-cancelado.png). Na aba Jogos, com a barra
/// inferior. Relê tudo a cada evento do Realtime. O pé tem as entradas e as
/// saídas (etapas A e B), o admin remove pela linha da lista, e o menu tem
/// Editar jogo, Admins do jogo e Cancelar jogo (etapa C).
class GameScreen extends ConsumerWidget {
  const GameScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameDetailProvider(gameId));
    return Scaffold(
      body: switch (game) {
        AsyncValue(:final value?) => _GameBody(game: value),
        AsyncError(:final error) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SafeArea(bottom: false, child: _BackOnly()),
            Expanded(
              child: ErrorStateView(
                error: error,
                onRetry: () => ref.invalidate(gameDetailProvider(gameId)),
              ),
            ),
          ],
        ),
        _ => const LoadingState(),
      },
    );
  }
}

/// Só o voltar, nos estados sem jogo (erro, não encontrado).
class _BackOnly extends StatelessWidget {
  const _BackOnly();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: _CircleButton(
          icon: Symbols.arrow_back,
          tooltip: AppLocalizations.of(context).commonBack,
          background: theme.colorScheme.surface,
          foreground: theme.colorScheme.onSurface,
          onPressed: () => _back(context),
        ),
      ),
    );
  }
}

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(Routes.games);
  }
}

class _GameBody extends ConsumerWidget {
  const _GameBody({required this.game});

  final GameDetail game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final footer = _footer(context, ref, now);
    final beforeStart = now.isBefore(game.startsAt);
    final waitlist = game.orderedWaitlist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(game: game, now: now),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Trio(game: game),
                      const SizedBox(height: 16),
                      _ReceiverCard(game: game),
                      if (_HistoryCard.shows(game)) ...[
                        const SizedBox(height: 16),
                        _HistoryCard(game: game),
                      ],
                      if (game.status == GameStatus.completed) ...[
                        const SizedBox(height: 16),
                        _SplitCard(game: game),
                      ],
                      const SizedBox(height: 24),
                      _ParticipantList(game: game, now: now),
                      // A espera só antes do início e com alguém nela.
                      if (beforeStart &&
                          game.status.isActive &&
                          waitlist.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _WaitlistSection(game: game, waitlist: waitlist),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: footer,
          ),
      ],
    );
  }

  /// A ação da pessoa no pé (telas.md, 7.3), com o jogo Aberto ou
  /// Confirmado. O relógio do aparelho só decide o que aparece: a recusa do
  /// servidor vira `SnackBar`, e a tela relê.
  Widget? _footer(BuildContext context, WidgetRef ref, DateTime now) {
    if (!game.status.isActive) return null;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final busy = ref.watch(gameActionsControllerProvider).isLoading;

    if (!now.isBefore(game.endsAt)) {
      // Depois do fim, o admin conclui (telas.md, 8.1).
      if (canComplete(game, now)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.gameCompleteHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l10n.gameComplete,
              onPressed: () => _openComplete(context, game.id),
            ),
          ],
        );
      }
      return InlineNotice(
        icon: Symbols.lock,
        color: theme.colorScheme.surfaceContainerHigh,
        iconColor: theme.colorScheme.onSurface,
        text: l10n.gameListLocked,
      );
    }
    final mine = game.myParticipant;
    if (mine != null) {
      // Quem saiu após o início fica sem pé: a falta já está registrada.
      if (mine.status != ParticipantStatus.active) return null;
      if (game.isReceiver) {
        return InlineNotice(
          icon: Symbols.lock,
          color: colors.split,
          text: l10n.gameReceiverCannotLeave,
        );
      }
      return DestructiveOutlinedButton(
        label: l10n.gameLeave,
        onPressed: busy ? null : () => _leave(context, ref, game),
      );
    }
    // As listas fecham no início (RN54, RN55).
    if (!now.isBefore(game.startsAt)) return null;

    Future<void> join() async {
      final error = await ref
          .read(gameActionsControllerProvider.notifier)
          .join(game.id);
      if (!context.mounted) return;
      if (error != null) {
        showErrorSnack(context, error);
      } else {
        showSnack(context, l10n.gameJoined);
      }
    }

    Future<void> joinWaitlist() async {
      final error = await ref
          .read(gameActionsControllerProvider.notifier)
          .joinWaitlist(game.id);
      if (!context.mounted) return;
      if (error != null) {
        showErrorSnack(context, error);
      } else {
        showSnack(context, l10n.gameJoinedWaitlist);
      }
    }

    Future<void> leaveWaitlist() async {
      final error = await ref
          .read(gameActionsControllerProvider.notifier)
          .leaveWaitlist(game.id);
      if (!context.mounted) return;
      if (error != null) {
        showErrorSnack(context, error);
      } else {
        showSnack(context, l10n.gameLeftWaitlist);
      }
    }

    final position = game.myWaitlistPosition;
    if (position != null) {
      if (game.status == GameStatus.open) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: l10n.gameJoin, loading: busy, onPressed: join),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : leaveWaitlist,
              child: Text(l10n.gameLeaveWaitlist),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InlineNotice(
            icon: Symbols.hourglass_top,
            color: colors.wait,
            text: l10n.gameWaitlistNotice('$position'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : leaveWaitlist,
            child: Text(l10n.gameLeaveWaitlist, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    // Fora das listas. Sem ser membro do grupo, ou num avulso, só pelo
    // convite, que chega na fatia 8.
    final hint = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!game.isGroupMember) {
      return Text(
        l10n.gameNeedsInvite,
        style: hint,
        textAlign: TextAlign.center,
      );
    }
    if (game.status == GameStatus.open) {
      return PrimaryButton(
        label: l10n.gameJoin,
        loading: busy,
        onPressed: join,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.gameFullHint, style: hint, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        PrimaryButton(
          label: l10n.gameJoinWaitlist,
          loading: busy,
          onPressed: joinWaitlist,
        ),
      ],
    );
  }
}

/// Sair da lista, com a confirmação destrutiva. A frase escolhe pelo relógio
/// do aparelho, porque é só aviso; o `SnackBar` segue o `outcome` do servidor
/// (telas.md, 7.3).
Future<void> _leave(
  BuildContext context,
  WidgetRef ref,
  GameDetail game,
) async {
  final l10n = AppLocalizations.of(context);
  final now = ref.read(clockProvider)();
  final body = !now.isBefore(game.startsAt)
      ? l10n.gameLeaveAfterStartBody
      : now.isAfter(game.cancellationDeadline)
      ? l10n.gameLeaveLateBody
      : l10n.gameLeaveOnTimeBody(
          l10n.gameDateTime(
            formatShortDate(game.cancellationDeadline),
            formatTime(game.cancellationDeadline),
          ),
        );
  final confirmed = await confirmDestructive(
    context,
    title: l10n.gameLeaveTitle,
    body: body,
    confirmLabel: l10n.gameLeave,
  );
  if (!confirmed || !context.mounted) return;
  final (outcome, error) = await ref
      .read(gameActionsControllerProvider.notifier)
      .leave(game.id);
  if (!context.mounted) return;
  if (error != null) {
    showErrorSnack(context, error);
    return;
  }
  showSnack(context, switch (outcome!) {
    LeaveOutcome.cancelledOnTime => l10n.gameLeftOnTime,
    LeaveOutcome.cancelledLate => l10n.gameLeftLate,
    LeaveOutcome.leftAfterStart => l10n.gameLeftAfterStart,
  });
}

/// Topo colorido (design-system.md, 7.8): `game` com o jogo Aberto, `wait`
/// com o Confirmado, `split` com o Concluído (telas.md, 8.1) e `surfaceHigh`
/// com o Cancelado.
class _Hero extends ConsumerWidget {
  const _Hero({required this.game, required this.now});

  final GameDetail game;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final cancelled = game.status == GameStatus.cancelled;
    final background = switch (game.status) {
      GameStatus.open => colors.game,
      GameStatus.confirmed => colors.wait,
      GameStatus.completed => colors.split,
      GameStatus.cancelled => theme.colorScheme.surfaceContainerHigh,
    };
    final foreground = cancelled ? theme.colorScheme.onSurface : colors.onBlock;
    final buttonBackground = cancelled
        ? theme.colorScheme.surface
        : colors.onBlock;
    final buttonForeground = cancelled
        ? theme.colorScheme.onSurface
        : background;
    final timeBadge = gameTimeBadge(
      context,
      status: game.status,
      startsAt: game.startsAt,
      endsAt: game.endsAt,
      now: now,
    );
    // O menu do admin, só com o que vale no momento (telas.md, 7.3).
    final canEdit =
        game.isAdmin && game.status.isActive && now.isBefore(game.startsAt);
    final mapsUrl = game.mapsUrl;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 12,
        24,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CircleButton(
                icon: Symbols.arrow_back,
                tooltip: l10n.commonBack,
                background: buttonBackground,
                foreground: buttonForeground,
                onPressed: () => _back(context),
              ),
              const Spacer(),
              if (mapsUrl != null)
                _CircleButton(
                  icon: Symbols.map,
                  tooltip: l10n.gameOpenMaps,
                  background: buttonBackground,
                  foreground: buttonForeground,
                  onPressed: () async {
                    final opened = await ref
                        .read(linkOpenerProvider)
                        .open(Uri.parse(mapsUrl));
                    if (!opened && context.mounted) {
                      showSnack(context, l10n.commonCannotOpenLink);
                    }
                  },
                ),
              if (game.isAdmin) ...[
                const SizedBox(width: 12),
                _AdminMenu(
                  game: game,
                  canEdit: canEdit,
                  canComplete: canComplete(game, now),
                  background: buttonBackground,
                  foreground: buttonForeground,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _GroupPill(
                label: game.groupName ?? l10n.gameStandalone,
                standalone: game.groupName == null,
                background: buttonBackground,
                foreground: theme.colorScheme.onSurface,
              ),
              GameStatusPill(status: game.status, outlined: true),
              ?timeBadge,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatShortDate(game.startsAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.gameTimeRange(
                          formatTime(game.startsAt),
                          formatTime(game.endsAt),
                        ),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Symbols.location_on, color: foreground, size: 22),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            game.locationName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SlotRing(
                occupied: game.occupiedSlots,
                limit: game.slotLimit,
                color: foreground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// O que o admin escolheu no menu.
enum _AdminAction { edit, complete, admins, cancel }

/// Concluir jogo, para o admin, depois do fim, com o jogo Aberto ou
/// Confirmado (telas.md, 8.1). O relógio do aparelho só decide o que
/// aparece: o servidor confere (`GAME_NOT_ENDED`).
bool canComplete(GameDetail game, DateTime now) =>
    game.isAdmin && game.status.isActive && !now.isBefore(game.endsAt);

void _openComplete(BuildContext context, String gameId) {
  context.pushNamed(Routes.gameComplete, pathParameters: {'gameId': gameId});
}

/// O botão `more_vert` do admin, com as opções que valem no momento
/// (telas.md, 7.3): Editar jogo antes do início; Admins do jogo sempre;
/// Cancelar jogo com o jogo Aberto ou Confirmado, mesmo depois do início
/// (RN43).
class _AdminMenu extends ConsumerWidget {
  const _AdminMenu({
    required this.game,
    required this.canEdit,
    required this.canComplete,
    required this.background,
    required this.foreground,
  });

  final GameDetail game;
  final bool canEdit;
  final bool canComplete;
  final Color background;
  final Color foreground;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.gameCancelTitle,
      body: l10n.gameCancelBody,
      confirmLabel: l10n.gameCancel,
    );
    if (!confirmed || !context.mounted) return;
    final error = await ref
        .read(gameActionsControllerProvider.notifier)
        .cancel(game.id);
    if (!context.mounted) return;
    error == null
        ? showSnack(context, l10n.gameCancelled)
        : showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    PopupMenuItem<_AdminAction> item(
      _AdminAction value,
      IconData icon,
      String label, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Flexible(
            child: Text(label, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
    return PopupMenuButton<_AdminAction>(
      tooltip: l10n.gameMenuLabel,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(Symbols.more_vert, color: foreground),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onSelected: (action) => switch (action) {
        _AdminAction.edit => context.pushNamed(
          Routes.gameEdit,
          pathParameters: {'gameId': game.id},
        ),
        _AdminAction.complete => _openComplete(context, game.id),
        _AdminAction.admins => context.pushNamed(
          Routes.gameAdmins,
          pathParameters: {'gameId': game.id},
        ),
        _AdminAction.cancel => _cancel(context, ref),
      },
      itemBuilder: (context) => [
        if (canEdit) item(_AdminAction.edit, Symbols.edit, l10n.gameEdit),
        if (canComplete)
          item(_AdminAction.complete, Symbols.task_alt, l10n.gameComplete),
        item(_AdminAction.admins, Symbols.shield_person, l10n.gameAdmins),
        if (game.status.isActive)
          item(
            _AdminAction.cancel,
            Symbols.event_busy,
            l10n.gameCancel,
            color: error,
          ),
      ],
    );
  }
}

class _GroupPill extends StatelessWidget {
  const _GroupPill({
    required this.label,
    required this.standalone,
    required this.background,
    required this.foreground,
  });

  final String label;
  final bool standalone;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            standalone ? Symbols.person : Symbols.groups,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anel segmentado das vagas (design-system.md, 7.11): um gomo por vaga, cheio
/// nas ocupadas.
class _SlotRing extends StatelessWidget {
  const _SlotRing({
    required this.occupied,
    required this.limit,
    required this.color,
  });

  final int occupied;
  final int limit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      width: 112,
      height: 112,
      child: CustomPaint(
        painter: _RingPainter(
          occupied: occupied,
          limit: limit,
          filled: color,
          empty: color.withValues(alpha: .18),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.gameSlotsCount('$occupied', '$limit'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 30,
                      color: color,
                    ),
                  ),
                  Text(
                    l10n.gameSlotsUnit,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.occupied,
    required this.limit,
    required this.filled,
    required this.empty,
  });

  final int occupied;
  final int limit;
  final Color filled;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final segments = limit < 1 ? 1 : limit;
    final sweep = 2 * math.pi / segments;
    // Com muitas vagas, o vão some para os gomos não virarem pontos.
    final gap = segments > 40 ? 0.0 : 0.06;
    for (var i = 0; i < segments; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = i < occupied ? filled : empty;
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.occupied != occupied ||
      old.limit != limit ||
      old.filled != filled ||
      old.empty != empty;
}

/// Trio de números (design-system.md, 7.10): vagas, estimativa por pessoa em
/// `split` e prazo.
class _Trio extends StatelessWidget {
  const _Trio({required this.game});

  final GameDetail game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = VoleiColors.of(context);
    final free = game.slotLimit - game.occupiedSlots;
    final share = game.shareCents;
    // Concluído: vagas, parte por vaga final e total; o prazo sai (8.1).
    if (game.status == GameStatus.completed && share != null) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GameTrioCard(
                label: l10n.gameTrioSlots,
                value: l10n.gameSlotsCount(
                  '${game.occupiedSlots}',
                  '${game.slotLimit}',
                ),
                caption: l10n.gameTrioAtStart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GameTrioCard(
                label: l10n.gameSharePerSlot,
                value: formatCents(share),
                caption: l10n.gameTrioFinal,
                color: colors.split,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GameTrioCard(
                label: l10n.gameTotal,
                value: formatCents(game.totalCents),
                caption: l10n.gameTrioVenue,
              ),
            ),
          ],
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GameTrioCard(
              label: l10n.gameTrioSlots,
              value: l10n.gameSlotsCount(
                '${game.occupiedSlots}',
                '${game.slotLimit}',
              ),
              caption: free > 0
                  ? l10n.gameTrioFreeSlots(free)
                  : l10n.gameTrioFull,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GameTrioCard(
              label: l10n.gameTrioPerPerson,
              value: formatCents(
                estimatedShareCents(game.totalCents, game.slotLimit),
              ),
              caption: l10n.gameTrioEstimate,
              color: colors.split,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GameTrioCard(
              label: l10n.gameTrioDeadline,
              value: formatTime(game.cancellationDeadline),
              caption: formatShortDate(game.cancellationDeadline),
            ),
          ),
        ],
      ),
    );
  }
}

/// O recebedor, com a chave Pix para quem ocupa vaga e para ele mesmo
/// (RF45, RN102). A chave vem de `get_profile_contact`; nula, a frase dos
/// demais.
class _ReceiverCard extends ConsumerWidget {
  const _ReceiverCard({required this.game});

  final GameDetail game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final key = game.receiverPixKey;
    final type = game.receiverPixKeyType;
    final mayView = game.isReceiver || game.myParticipant != null;
    final showKey = mayView && key != null && type != null;
    final name = game.isReceiver
        ? l10n.groupMemberYou(game.receiverName)
        : game.receiverName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _PersonAvatar(
                id: game.receiverId,
                name: game.receiverName,
                photoPath: game.receiverPhotoPath,
                isYou: game.isReceiver,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    VoleiBadge(label: l10n.gameReceiver, tone: colors.neutral),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showKey)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  l10n.profilePixSummary(
                    _pixTypeLabel(l10n, type),
                    formatPixKey(type, key),
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Symbols.content_copy),
                  label: Text(l10n.gamePixCopy),
                  onPressed: () async {
                    // A chave sem formatação, como o Pix a recebe.
                    await Clipboard.setData(ClipboardData(text: key));
                    if (context.mounted) showSnack(context, l10n.gamePixCopied);
                  },
                ),
              ],
            )
          else
            Text(
              l10n.gamePixOnlyParticipants,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Rótulo do tipo da chave (docs/copy.md, 6.6). A mesma tabela da feature
/// `auth`, que esta feature não importa (docs/arquitetura-app.md, seção 2).
String _pixTypeLabel(AppLocalizations l10n, PixKeyType type) => switch (type) {
  PixKeyType.cpf => l10n.pixTypeCpf,
  PixKeyType.cnpj => l10n.pixTypeCnpj,
  PixKeyType.email => l10n.pixTypeEmail,
  PixKeyType.phone => l10n.pixTypePhone,
  PixKeyType.random => l10n.pixTypeRandom,
};

/// Avatar redondo de uma pessoa do jogo, com a foto pela URL assinada.
class _PersonAvatar extends ConsumerWidget {
  const _PersonAvatar({
    required this.id,
    required this.name,
    this.photoPath,
    this.isYou = false,
  });

  final String id;
  final String name;
  final String? photoPath;
  final bool isYou;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return VoleiAvatar(id: id, name: name, isYou: isYou, imageUrl: url);
  }
}

void _openPerson(BuildContext context, String gameId, String userId) {
  context.pushNamed(
    Routes.gamePerson,
    pathParameters: {'gameId': gameId, 'userId': userId},
  );
}

/// Lista de presença (RF46, RN52): as passagens que ocupam vaga, por ordem de
/// `joined_at`, numeradas.
class _ParticipantList extends ConsumerWidget {
  const _ParticipantList({required this.game, required this.now});

  final GameDetail game;
  final DateTime now;

  /// O admin, antes do início, abre a sheet sobre quem não é o recebedor;
  /// nos outros casos, o toque abre o perfil (telas.md, 7.3).
  bool _opensSheet(GameParticipant person) =>
      game.isAdmin &&
      game.status.isActive &&
      now.isBefore(game.startsAt) &&
      person.status == ParticipantStatus.active &&
      person.userId != game.receiverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final rows = game.participants.where((p) => p.status.takesSlot).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gameListTitle('${game.occupiedSlots}', '${game.slotLimit}'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (rows.isNotEmpty)
          ListCard(
            children: [
              for (var i = 0; i < rows.length; i++)
                Builder(
                  builder: (context) {
                    final person = rows[i];
                    final isYou = person.userId == game.viewerId;
                    final badges = <Widget>[
                      if (person.userId == game.receiverId)
                        VoleiBadge(
                          label: l10n.gameReceiver,
                          tone: colors.neutral,
                        ),
                      if (game.isAdminUser(person.userId))
                        VoleiBadge(label: l10n.gameAdmin, tone: colors.neutral),
                      // No concluído, Faltou no lugar de Saiu após o início
                      // (telas.md, 8.1).
                      if (game.status == GameStatus.completed && person.absent)
                        VoleiBadge(
                          label: l10n.gameAbsentBadge,
                          tone: colors.bad,
                          dot: true,
                        )
                      else if (person.status ==
                          ParticipantStatus.leftAfterStart)
                        VoleiBadge(
                          label: l10n.gameLeftAfterStartBadge,
                          tone: colors.bad,
                          dot: true,
                        ),
                    ];
                    return ListRow(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontSize: 24,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PersonAvatar(
                            id: person.userId,
                            name: person.displayName,
                            photoPath: person.photoPath,
                            isYou: isYou,
                          ),
                        ],
                      ),
                      title: isYou
                          ? l10n.groupMemberYou(person.displayName)
                          : person.displayName,
                      badge: badges.isEmpty
                          ? null
                          : Wrap(spacing: 8, runSpacing: 4, children: badges),
                      // A própria linha não é tocável (telas.md, 7.3).
                      onTap: isYou
                          ? null
                          : _opensSheet(person)
                          ? () => _participantSheet(context, ref, game, person)
                          : () => _openPerson(context, game.id, person.userId),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// Sheet do admin sobre um participante (game-participante.png): Ver perfil e
/// Remover da lista, esta com a confirmação destrutiva (RN58).
Future<void> _participantSheet(
  BuildContext context,
  WidgetRef ref,
  GameDetail game,
  GameParticipant person,
) async {
  final l10n = AppLocalizations.of(context);
  final remove = await showVoleiSheet<bool>(context, (context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(person.displayName, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        SheetOptions(
          options: [
            SheetOption(
              icon: Symbols.person,
              label: l10n.groupMemberViewProfile,
              onTap: () => Navigator.of(context).pop(false),
            ),
            SheetOption(
              icon: Symbols.person_remove,
              label: l10n.gameParticipantRemove,
              color: theme.colorScheme.error,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
  });
  if (remove == null || !context.mounted) return;
  if (!remove) {
    _openPerson(context, game.id, person.userId);
    return;
  }
  final confirmed = await confirmDestructive(
    context,
    title: l10n.gameParticipantRemoveTitle(person.displayName),
    body: l10n.gameParticipantRemoveBody(person.displayName),
    confirmLabel: l10n.gameParticipantRemoveConfirm,
  );
  if (!confirmed || !context.mounted) return;
  final error = await ref
      .read(gameActionsControllerProvider.notifier)
      .remove(game.id, person.userId);
  if (!context.mounted) return;
  if (error != null) {
    showErrorSnack(context, error);
  } else {
    showSnack(context, l10n.gameParticipantRemoved(person.displayName));
  }
}

/// Lista de espera atual, por ordem de `joined_at`, com a posição (RF49).
class _WaitlistSection extends StatelessWidget {
  const _WaitlistSection({required this.game, required this.waitlist});

  final GameDetail game;
  final List<WaitlistEntry> waitlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gameWaitlistTitle('${waitlist.length}'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ListCard(
          children: [
            for (var i = 0; i < waitlist.length; i++)
              Builder(
                builder: (context) {
                  final person = waitlist[i];
                  final isYou = person.userId == game.viewerId;
                  return ListRow(
                    leading: _PersonAvatar(
                      id: person.userId,
                      name: person.displayName,
                      photoPath: person.photoPath,
                      isYou: isYou,
                    ),
                    title: isYou
                        ? l10n.groupMemberYou(person.displayName)
                        : person.displayName,
                    badge: VoleiBadge(
                      label: l10n.gameWaitlistPosition('${i + 1}'),
                      tone: colors.waiting,
                      dot: true,
                    ),
                    onTap: isYou
                        ? null
                        : () => _openPerson(context, game.id, person.userId),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Card do Rateio no jogo concluído (telas.md, 8.1; design-system.md, 7.13):
/// o próprio valor com o rótulo e o selo, ou `splitNoCharge`, e a seta.
class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.game});

  final GameDetail game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final charge = game.myCharge;
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.gameSplit,
          pathParameters: {'gameId': game.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconSquare(
                icon: Symbols.pie_chart,
                background: colors.split,
                foreground: colors.onBlock,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.splitCardTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (charge == null)
                      Text(l10n.splitNoCharge, style: soft)
                    else ...[
                      Text(chargeKindLabel(l10n, charge.kind), style: soft),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatCents(charge.amountCents),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          ChargeStatusBadge(status: charge.status),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Symbols.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card "Sua participação" (RF65; telas.md, 8.1; game-concluido.png): uma
/// linha por passagem de quem lê, por ordem de `joined_at`, e, com o jogo
/// concluído, o valor a pagar ou `splitNoCharge`. Aparece com outra passagem,
/// falta ou multa; quem só jogou e tem a parte não o vê (decisão de
/// 18/11/2026, S71).
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.game});

  final GameDetail game;

  static bool shows(GameDetail game) =>
      game.myPassages.any((p) => _Entry.of(p) != null) ||
      (game.myCharge?.kind.isPenalty ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = [
      for (final passage in game.myPassages) ?_Entry.of(passage),
    ];
    final completed = game.status == GameStatus.completed;
    final rows = <Widget>[
      for (final entry in entries) _HistoryRow(entry: entry),
      if (completed) _HistoryChargeRow(charge: game.myCharge),
    ];

    return Container(
      key: const Key('historyCard'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.historyTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(color: theme.colorScheme.outlineVariant, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// O que aconteceu numa passagem: o ícone, a linha e as linhas de apoio.
class _Entry {
  const _Entry(this.icon, this.text, this.notes);

  final IconData icon;
  final String Function(AppLocalizations l10n) text;
  final List<String Function(AppLocalizations l10n)> notes;

  /// Nulo para a passagem `active` sem falta: ela não vira linha.
  static _Entry? of(GamePassage passage) {
    final left = passage.leftAt;
    String date() => left == null ? '' : formatShortDate(left);
    String time() => left == null ? '' : formatTime(left);
    String Function(AppLocalizations) absence() =>
        passage.absenceSource == AbsenceSource.leftAfterStart
        ? (l10n) => l10n.historyAbsentLeft
        : (l10n) => l10n.historyMarkedAbsent;

    switch (passage.status) {
      case ParticipantStatus.cancelled:
        final voided = passage.cancellationVoidedAt;
        return _Entry(
          Symbols.logout,
          passage.lateCancellation
              ? (l10n) => l10n.historyCancelledLate(date(), time())
              : (l10n) => l10n.historyCancelledOnTime(date(), time()),
          [
            if (voided != null)
              (l10n) => l10n.historyVoided(formatTime(voided)),
            if (passage.lateCancellationExempt) (l10n) => l10n.historyExempt,
          ],
        );
      case ParticipantStatus.leftAfterStart:
        return _Entry(
          Symbols.directions_run,
          (l10n) => l10n.historyLeftAfterStart(time()),
          [if (passage.absent) absence()],
        );
      case ParticipantStatus.removed:
        return switch (passage.removalReason) {
          RemovalReason.byAdmin => _Entry(
            Symbols.person_remove,
            (l10n) => l10n.historyRemovedByAdmin(date()),
            const [],
          ),
          RemovalReason.leftGroup => _Entry(
            Symbols.group_remove,
            (l10n) => l10n.historyRemovedGroupLeft(date()),
            const [],
          ),
          _ => null,
        };
      case ParticipantStatus.active:
        return passage.absent
            ? _Entry(Symbols.event_busy, absence(), const [])
            : null;
    }
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconSquare(icon: entry.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.text(l10n), style: theme.textTheme.bodyLarge),
                for (final note in entry.notes)
                  Text(
                    note(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A linha do valor no fim do card: rótulo, "Para {recebedor}", valor e
/// selo, ou `splitNoCharge`.
class _HistoryChargeRow extends StatelessWidget {
  const _HistoryChargeRow({required this.charge});

  final GameCharge? charge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final value = charge;
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(l10n.splitNoCharge, style: soft),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          IconSquare(
            icon: Symbols.receipt_long,
            background: value.status == ChargeStatus.waived ? null : colors.owe,
            foreground: value.status == ChargeStatus.waived
                ? null
                : colors.onBlock,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chargeKindLabel(l10n, value.kind),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(l10n.splitOwedTo(value.receiverName), style: soft),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCents(value.amountCents),
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  ChargeStatusBadge(status: value.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
