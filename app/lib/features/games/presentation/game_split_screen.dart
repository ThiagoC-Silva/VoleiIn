import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/badge.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';
import 'game_badges.dart';
import 'game_controllers.dart';
import 'game_trio.dart';
import 'games_providers.dart';
import 'split_text.dart';

/// Rateio do jogo (RF72 a RF74; docs/ui/telas.md, 8.3; gameSplit.png e
/// gameSplit-recebedor.png). Na aba Jogos, com a barra inferior. Todos veem o
/// cabeçalho e o próprio valor; o recebedor e os admins do jogo veem também os
/// totais e todos os valores (RN76). Os totais só somam `amount_cents` já
/// gravados, em inteiros (contratos-api.md, seção 9). Tocar num valor abre o
/// que a pessoa pode fazer com ele: o recebedor do valor marca como pago e
/// reverte (RF84, RF85), e o admin do jogo isenta a multa (RF64; 9.5;
/// gameSplit-marcarPago.png). Sem nada a fazer, abre o perfil.
class GameSplitScreen extends ConsumerWidget {
  const GameSplitScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final split = ref.watch(gameSplitProvider(gameId));
    // Mantém o controller vivo durante a ação.
    ref.watch(gameCompletionControllerProvider);
    Future<void> reload() => ref.refresh(gameSplitProvider(gameId).future);

    return Scaffold(
      appBar: InnerAppBar(title: l10n.splitCardTitle),
      body: switch (split) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: reload,
          child: _SplitBody(split: value),
        ),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(gameSplitProvider(gameId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _SplitBody extends StatelessWidget {
  const _SplitBody({required this.split});

  final GameSplit split;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final game = split.game;
    final seesAll = game.isReceiver || game.isAdmin;
    final mine = split.charges.where((c) => c.payerId == game.viewerId);
    // O antigo recebedor que não é admin (RN31.2; telas.md, 9.5).
    final owedToYou = seesAll
        ? const <GameCharge>[]
        : (split.charges.where((c) => c.receiverId == game.viewerId).toList()
            ..sort(_byName));
    final active =
        split.charges.where((c) => c.status != ChargeStatus.waived).toList()
          ..sort(_byName);
    final waived =
        split.charges.where((c) => c.status == ChargeStatus.waived).toList()
          ..sort(_byName);
    // Por conta do recebedor: total − soma dos não Isentos (RN74).
    final covered =
        game.totalCents - active.fold<int>(0, (sum, c) => sum + c.amountCents);
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Listas curtas (uma linha por vaga): tudo montado, e o puxar para
    // atualizar vale mesmo com pouco conteúdo.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.calendar_month,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatShortDate(game.startsAt)} · ${game.locationName}',
                  style: soft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4,
                  child: GameTrioCard(
                    label: l10n.gameTotal,
                    value: formatCents(game.totalCents),
                    caption: l10n.gameTrioVenue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: GameTrioCard(
                    label: l10n.gameTrioSlots,
                    value: '${game.slotLimit}',
                    caption: l10n.splitTrioLimit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: GameTrioCard(
                    label: l10n.gameSharePerSlot,
                    value: formatCents(game.shareCents ?? 0),
                    caption: l10n.splitShareFormula(
                      formatCents(game.totalCents),
                      '${game.slotLimit}',
                    ),
                    color: colors.split,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.splitYourValue, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (mine.isNotEmpty)
            for (final charge in mine) ...[
              _MyCharge(charge: charge),
              const SizedBox(height: 12),
            ]
          else
            _NoCharge(text: _noChargeReason(l10n, split, covered)),
          if (owedToYou.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(l10n.splitOwedToYou, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ListCard(
              children: [
                for (final charge in owedToYou)
                  _ChargeRow(game: game, charge: charge, showReceiver: false),
              ],
            ),
          ],
          if (seesAll) ...[
            const SizedBox(height: 24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _TotalBlock(
                      key: const Key('splitReceivedTotal'),
                      label: l10n.splitReceived,
                      cents: _sum(active, {ChargeStatus.paid}),
                      color: colors.receive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TotalBlock(
                      key: const Key('splitPendingTotal'),
                      label: l10n.splitPending,
                      cents: _sum(active, {
                        ChargeStatus.pending,
                        ChargeStatus.underReview,
                      }),
                      color: colors.owe,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CoveredRow(game: game, covered: covered),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.splitCharges, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ListCard(
                children: [
                  for (final charge in active)
                    _ChargeRow(game: game, charge: charge),
                ],
              ),
            ],
            if (waived.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.splitWaived, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ListCard(
                children: [
                  for (final charge in waived)
                    _ChargeRow(game: game, charge: charge),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(l10n.splitNoChargeSection, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ListCard(children: _noChargeRows(context, split)),
          ],
        ],
      ),
    );
  }

  static int _byName(GameCharge a, GameCharge b) =>
      a.payerName.toLowerCase().compareTo(b.payerName.toLowerCase());

  static int _sum(List<GameCharge> charges, Set<ChargeStatus> statuses) =>
      charges
          .where((c) => statuses.contains(c.status))
          .fold<int>(0, (sum, c) => sum + c.amountCents);

  /// O motivo de quem não tem valor (telas.md, 8.3), pelas passagens.
  static String _noChargeReason(
    AppLocalizations l10n,
    GameSplit split,
    int covered,
  ) {
    final game = split.game;
    if (game.isReceiver) {
      return covered < 0
          ? receiverCoveredText(l10n, covered, game.receiverName)
          : l10n.splitNoChargeReceiver(formatCents(covered));
    }
    final passages = split.passages.where((p) => p.userId == game.viewerId);
    if (passages.any((p) => p.lateCancellationExempt)) {
      return l10n.splitNoChargeExempt;
    }
    if (passages.any(
      (p) => p.status == ParticipantStatus.cancelled && !p.lateCancellation,
    )) {
      return l10n.splitNoChargeOnTime;
    }
    if (passages.any((p) => p.status == ParticipantStatus.removed)) {
      return l10n.splitNoChargeRemoved;
    }
    return l10n.splitNoCharge;
  }

  /// O recebedor e quem teve a multa isentada na conclusão (RN62).
  static List<Widget> _noChargeRows(BuildContext context, GameSplit split) {
    final l10n = AppLocalizations.of(context);
    final game = split.game;
    final payers = {for (final c in split.charges) c.payerId};
    final exempt = <String, GamePassage>{
      for (final p in split.passages)
        if (p.lateCancellationExempt &&
            !payers.contains(p.userId) &&
            p.userId != game.receiverId)
          p.userId: p,
    };
    final people = exempt.values.toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return [
      _PersonRow(
        game: game,
        userId: game.receiverId,
        name: game.receiverName,
        photoPath: game.receiverPhotoPath,
        badge: VoleiBadge.neutral(context, l10n.gameReceiver),
      ),
      for (final person in people)
        _PersonRow(
          game: game,
          userId: person.userId,
          name: person.displayName,
          photoPath: person.photoPath,
          subtitle: l10n.historyExempt,
        ),
    ];
  }
}

void _openPerson(BuildContext context, String gameId, String userId) {
  context.pushNamed(
    Routes.gamePerson,
    pathParameters: {'gameId': gameId, 'userId': userId},
  );
}

/// O próprio valor, no bloco grande (gameSplit.png): `owe` enquanto falta
/// pagar, `receive` no Pago e neutro no Isento. Tocar, ou **Pagar** no
/// Pendente, abre o valor a pagar, na aba Cobranças (telas.md, 9.2).
class _MyCharge extends StatelessWidget {
  const _MyCharge({required this.charge});

  final GameCharge charge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final waived = charge.status == ChargeStatus.waived;
    final background = switch (charge.status) {
      ChargeStatus.paid => colors.receive,
      ChargeStatus.waived => theme.colorScheme.surface,
      _ => colors.owe,
    };
    final text = waived ? theme.colorScheme.onSurface : colors.onBlock;

    void open() =>
        context.goNamed(Routes.charge, pathParameters: {'chargeId': charge.id});

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chargeKindLabel(l10n, charge.kind),
                style: theme.textTheme.titleMedium?.copyWith(color: text),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCents(charge.amountCents),
                  style: theme.textTheme.displayLarge?.copyWith(color: text),
                ),
              ),
              const SizedBox(height: 8),
              ChargeStatusBadge(status: charge.status, onBlock: true),
              if (waived) ...[
                const SizedBox(height: 8),
                Text(
                  chargeWaivedLabel(l10n, charge.waiveReason),
                  style: theme.textTheme.bodyMedium?.copyWith(color: text),
                ),
              ],
              const SizedBox(height: 16),
              Divider(color: text.withValues(alpha: .2), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  VoleiAvatar(
                    id: charge.receiverId,
                    name: charge.receiverName,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.splitOwedTo(charge.receiverName),
                      style: theme.textTheme.bodyLarge?.copyWith(color: text),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(Symbols.chevron_right, color: text),
                  ),
                ],
              ),
              if (charge.status == ChargeStatus.pending) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: text,
                    side: BorderSide(color: text, width: 1.5),
                  ),
                  onPressed: open,
                  child: Text(l10n.chargePay),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCharge extends StatelessWidget {
  const _NoCharge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(text, style: theme.textTheme.bodyLarge),
    );
  }
}

/// Um total do recebedor (gameSplit-recebedor.png): Recebido em `receive`,
/// Pendente em `owe`.
class _TotalBlock extends StatelessWidget {
  const _TotalBlock({
    required this.label,
    required this.cents,
    required this.color,
    super.key,
  });

  final String label;
  final int cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onBlock,
              fontWeight: FontWeight.w700,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCents(cents),
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: 32,
                color: colors.onBlock,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Por conta de {recebedor}", ou a frase do arredondamento (R04).
class _CoveredRow extends StatelessWidget {
  const _CoveredRow({required this.game, required this.covered});

  final GameDetail game;
  final int covered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: covered < 0
          ? Text(
              receiverCoveredText(l10n, covered, game.receiverName),
              style: theme.textTheme.bodyLarge,
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.splitReceiverCovers(game.receiverName),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatCents(covered),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Linha de valor (telas-fatia-5.md): avatar, nome, rótulo do `kind`, valor
/// e selo. "Para {nome}" quando o valor é de outro recebedor (RN31).
class _ChargeRow extends ConsumerWidget {
  const _ChargeRow({
    required this.game,
    required this.charge,
    this.showReceiver = true,
  });

  final GameDetail game;
  final GameCharge charge;

  /// "Para {nome}" quando o valor é de outro recebedor.
  final bool showReceiver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isYou = charge.payerId == game.viewerId;
    final soft = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final path = charge.payerPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;

    final actions = _chargeActions(game, charge);
    return InkWell(
      onTap: actions.isNotEmpty
          ? () => _showActions(context, ref, game, charge, actions)
          : isYou
          ? null
          : () => _openPerson(context, game.id, charge.payerId),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              VoleiAvatar(
                id: charge.payerId,
                name: charge.payerName,
                isYou: isYou,
                imageUrl: url,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isYou
                          ? l10n.groupMemberYou(charge.payerName)
                          : charge.payerName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(chargeKindLabel(l10n, charge.kind), style: soft),
                    if (showReceiver && charge.receiverId != game.receiverId)
                      Text(l10n.splitOwedTo(charge.receiverName), style: soft),
                    if (charge.status == ChargeStatus.waived)
                      Text(
                        chargeWaivedLabel(l10n, charge.waiveReason),
                        style: soft,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // O valor e o selo encolhem juntos com a fonte grande, sem cortar.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatCents(charge.amountCents),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ChargeStatusBadge(status: charge.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O que se faz com um valor no Rateio.
enum _ChargeAction { review, markPaid, revert, waive, profile }

/// As opções de quem lê neste valor (telas.md, 9.5). Só decide o que aparece:
/// o servidor confere o papel e o estado.
List<_ChargeAction> _chargeActions(GameDetail game, GameCharge charge) {
  final isChargeReceiver = charge.receiverId == game.viewerId;
  final pending = charge.status == ChargeStatus.pending;
  final actions = [
    // O comprovante só abre para o recebedor dele (RF87).
    if (isChargeReceiver &&
        charge.status == ChargeStatus.underReview &&
        charge.reviewReceiptId != null)
      _ChargeAction.review,
    if (isChargeReceiver && pending) _ChargeAction.markPaid,
    if (isChargeReceiver &&
        charge.status == ChargeStatus.paid &&
        charge.paidVia == PaymentMethod.manual)
      _ChargeAction.revert,
    if (game.isAdmin && pending && charge.kind.isPenalty) _ChargeAction.waive,
  ];
  // Sem ação, o toque já abre o perfil; o próprio perfil não abre daqui.
  if (actions.isNotEmpty && charge.payerId != game.viewerId) {
    actions.add(_ChargeAction.profile);
  }
  return actions;
}

/// Sheet com o avatar, o nome e as opções; a confirmação, em tom normal; e a
/// função do servidor. Depois, com sucesso ou erro, a tela relê.
Future<void> _showActions(
  BuildContext context,
  WidgetRef ref,
  GameDetail game,
  GameCharge charge,
  List<_ChargeAction> actions,
) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showVoleiSheet<_ChargeAction>(
    context,
    (context) => _ChargeSheet(charge: charge, actions: actions),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == _ChargeAction.profile) {
    _openPerson(context, game.id, charge.payerId);
    return;
  }
  // O comprovante abre na aba Cobranças (telas.md, 9.4) e, ao voltar, o
  // Rateio relê.
  if (chosen == _ChargeAction.review) {
    context.goNamed(
      Routes.receipt,
      pathParameters: {'receiptId': charge.reviewReceiptId!},
    );
    return;
  }

  final name = charge.payerName;
  final confirmed = await switch (chosen) {
    _ChargeAction.markPaid => confirmAction(
      context,
      title: l10n.markPaidTitle(name, formatCents(charge.amountCents)),
      body: l10n.markPaidBody,
      confirmLabel: l10n.markPaidAction,
    ),
    _ChargeAction.revert => confirmAction(
      context,
      title: l10n.revertTitle(name),
      body: l10n.revertBody(name),
      confirmLabel: l10n.revertAction,
    ),
    _ => confirmAction(
      context,
      title: l10n.waiveTitle(name),
      body: l10n.waiveBody,
      confirmLabel: l10n.waiveAction,
    ),
  };
  if (!confirmed || !context.mounted) return;

  final controller = ref.read(gameCompletionControllerProvider.notifier);
  final error = await switch (chosen) {
    _ChargeAction.markPaid => controller.markPaid(
      gameId: game.id,
      chargeId: charge.id,
    ),
    _ChargeAction.revert => controller.revert(
      gameId: game.id,
      chargeId: charge.id,
    ),
    _ => controller.waive(gameId: game.id, chargeId: charge.id),
  };
  if (!context.mounted) return;
  ref.invalidate(gameSplitProvider(game.id));
  if (error == null) {
    showSnack(context, switch (chosen) {
      _ChargeAction.markPaid => l10n.markedPaid,
      _ChargeAction.revert => l10n.paymentReverted,
      _ => l10n.penaltyWaived,
    });
    return;
  }
  showErrorSnack(context, error);
  // Deixou de ser admin: volta ao detalhe (telas.md, seção 8).
  if (error.code == ErrorCode.notGameAdmin) {
    context.goNamed(Routes.game, pathParameters: {'gameId': game.id});
  }
}

class _ChargeSheet extends ConsumerWidget {
  const _ChargeSheet({required this.charge, required this.actions});

  final GameCharge charge;
  final List<_ChargeAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final path = charge.payerPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            VoleiAvatar(
              id: charge.payerId,
              name: charge.payerName,
              imageUrl: url,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(charge.payerName, style: theme.textTheme.headlineMedium),
                  Text(
                    [
                      chargeKindLabel(l10n, charge.kind),
                      formatCents(charge.amountCents),
                      chargeStatusLabel(l10n, charge.status),
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SheetOptions(
          options: [
            for (final action in actions)
              SheetOption(
                icon: switch (action) {
                  _ChargeAction.review => Symbols.receipt_long,
                  _ChargeAction.markPaid => Symbols.paid,
                  _ChargeAction.revert => Symbols.undo,
                  _ChargeAction.waive => Symbols.money_off,
                  _ChargeAction.profile => Symbols.person,
                },
                label: switch (action) {
                  _ChargeAction.review => l10n.reviewReceiptAction,
                  _ChargeAction.markPaid => l10n.markPaidAction,
                  _ChargeAction.revert => l10n.revertAction,
                  _ChargeAction.waive => l10n.waiveAction,
                  _ChargeAction.profile => l10n.groupMemberViewProfile,
                },
                subtitle: switch (action) {
                  _ChargeAction.review => null,
                  _ChargeAction.markPaid => l10n.markPaidHint,
                  _ChargeAction.revert => l10n.revertHint,
                  _ChargeAction.waive => l10n.waiveActionHint,
                  _ChargeAction.profile => null,
                },
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ],
    );
  }
}

/// Linha de quem não tem valor a pagar.
class _PersonRow extends ConsumerWidget {
  const _PersonRow({
    required this.game,
    required this.userId,
    required this.name,
    this.photoPath,
    this.subtitle,
    this.badge,
  });

  final GameDetail game;
  final String userId;
  final String name;
  final String? photoPath;
  final String? subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isYou = userId == game.viewerId;
    final path = photoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return ListRow(
      leading: VoleiAvatar(id: userId, name: name, isYou: isYou, imageUrl: url),
      title: isYou ? l10n.groupMemberYou(name) : name,
      subtitle: subtitle,
      badge: badge,
      onTap: isYou ? null : () => _openPerson(context, game.id, userId),
    );
  }
}
