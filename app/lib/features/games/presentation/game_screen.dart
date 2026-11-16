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
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/pix_key.dart';
import '../domain/game_models.dart';
import 'game_badges.dart';
import 'game_controllers.dart';
import 'games_providers.dart';

/// Detalhe do jogo (RF37, RF45 a RF47, RF49, RF55; docs/ui/telas.md, 7.3;
/// game.png, game-admin.png, game-confirmado.png, game-espera.png,
/// game-andamento.png e game-cancelado.png). Na aba Jogos, com a barra
/// inferior. Relê tudo a cada evento do Realtime. Nesta etapa, o pé só tem as
/// entradas, e o menu só tem Editar jogo (research R12 de
/// specs/003-jogo-etapa-a).
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
      return InlineNotice(
        icon: Symbols.lock,
        color: theme.colorScheme.surfaceContainerHigh,
        iconColor: theme.colorScheme.onSurface,
        text: l10n.gameListLocked,
      );
    }
    final mine = game.myParticipant;
    if (mine != null) {
      if (mine.status == ParticipantStatus.active && game.isReceiver) {
        return InlineNotice(
          icon: Symbols.lock,
          color: colors.split,
          text: l10n.gameReceiverCannotLeave,
        );
      }
      // Sair da lista chega na etapa B.
      return null;
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

    final position = game.myWaitlistPosition;
    if (position != null) {
      if (game.status == GameStatus.open) {
        return PrimaryButton(
          label: l10n.gameJoin,
          loading: busy,
          onPressed: join,
        );
      }
      return InlineNotice(
        icon: Symbols.hourglass_top,
        color: colors.wait,
        text: l10n.gameWaitlistNotice('$position'),
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

/// Topo colorido (design-system.md, 7.8): `game` com o jogo Aberto, `wait`
/// com o Confirmado e `surfaceHigh` com o Cancelado.
class _Hero extends ConsumerWidget {
  const _Hero({required this.game, required this.now});

  final GameDetail game;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final cancelled = !game.status.isActive;
    final background = switch (game.status) {
      GameStatus.open => colors.game,
      GameStatus.confirmed => colors.wait,
      _ => theme.colorScheme.surfaceContainerHigh,
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
              if (canEdit) ...[
                const SizedBox(width: 12),
                _AdminMenu(
                  gameId: game.id,
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

/// O botão `more_vert` do admin. Nesta etapa, só com Editar jogo.
class _AdminMenu extends StatelessWidget {
  const _AdminMenu({
    required this.gameId,
    required this.background,
    required this.foreground,
  });

  final String gameId;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.gameMenuLabel,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(56, 56),
      ),
      icon: Icon(Symbols.more_vert, color: foreground),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      onSelected: (_) => context.pushNamed(
        Routes.gameEdit,
        pathParameters: {'gameId': gameId},
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: Routes.gameEdit,
          child: Row(
            children: [
              const Icon(Symbols.edit),
              const SizedBox(width: 16),
              Flexible(child: Text(l10n.gameEdit)),
            ],
          ),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TrioCard(
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
            child: _TrioCard(
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
            child: _TrioCard(
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

class _TrioCard extends StatelessWidget {
  const _TrioCard({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
  });

  final String label;
  final String value;
  final String caption;

  /// Cor de significado, com o texto navy dos blocos.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final text = color == null ? theme.colorScheme.onSurface : colors.onBlock;
    final soft = color == null
        ? theme.colorScheme.onSurfaceVariant
        : colors.onBlock;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: soft)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: 26,
                color: text,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(color: soft),
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
class _ParticipantList extends StatelessWidget {
  const _ParticipantList({required this.game, required this.now});

  final GameDetail game;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
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
                      if (person.status == ParticipantStatus.leftAfterStart)
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
