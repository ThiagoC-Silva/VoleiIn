import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../../games/domain/charge_models.dart';
import '../../games/presentation/game_badges.dart';
import '../../games/presentation/games_providers.dart';
import '../../games/presentation/split_text.dart';

/// Cobranças (RF75, RF76; docs/ui/telas.md, 8.5; charges.png e
/// charges-vazio.png): os atalhos dos totais a pagar e a receber, uma linha
/// por valor a pagar e uma por jogo a receber. Entre os atalhos e A pagar,
/// **Para conferir**: os comprovantes Em análise de quem lê (9.1). Os totais só somam
/// `amount_cents` já gravados, em inteiros (contratos-api.md, seção 9). Tocar
/// numa linha de A pagar abre o valor a pagar (9.1); numa de A receber, o
/// Rateio do jogo, na aba Jogos.
class ChargesScreen extends ConsumerStatefulWidget {
  const ChargesScreen({super.key});

  @override
  ConsumerState<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends ConsumerState<ChargesScreen> {
  final _toPayKey = GlobalKey();
  final _toReceiveKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charges = ref.watch(myChargesProvider);
    Future<void> refresh() => ref.refresh(myChargesProvider.future);

    return RootTabScaffold(
      title: l10n.chargesTitle,
      body: switch (charges) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: refresh,
          child: value.isEmpty
              ? EmptyState(
                  icon: Symbols.payments,
                  title: l10n.chargesEmptyTitle,
                  body: l10n.chargesEmptyBody,
                )
              : _content(context, value),
        ),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(myChargesProvider),
        ),
        _ => const LoadingState(),
      },
    );
  }

  Widget _content(BuildContext context, ChargesOverview overview) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final empty = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TotalShortcut(
                  label: l10n.chargesToPay,
                  cents: overview.toPayCents,
                  support: l10n.chargesToPayGames(overview.toPayGames),
                  color: colors.owe,
                  onTap: () => _scrollTo(_toPayKey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalShortcut(
                  label: l10n.chargesToReceive,
                  cents: overview.toReceiveCents,
                  support: l10n.chargesToReceivePeople(
                    overview.toReceivePeople,
                  ),
                  color: colors.receive,
                  onTap: () => _scrollTo(_toReceiveKey),
                ),
              ),
            ],
          ),
        ),
        if (overview.toReview.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.chargesToReview(overview.toReview.length),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListCard(
            children: [
              for (final line in overview.toReview) _ToReviewRow(line: line),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(
          l10n.chargesToPay,
          key: _toPayKey,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (overview.toPay.isEmpty)
          Text(l10n.chargesNothingToPay, style: empty)
        else
          ListCard(
            children: [
              for (final line in overview.toPay) _ToPayRow(line: line),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          l10n.chargesToReceive,
          key: _toReceiveKey,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (overview.toReceive.isEmpty)
          Text(l10n.chargesNothingToReceive, style: empty)
        else
          ListCard(
            children: [
              for (final game in overview.toReceive) _ToReceiveRow(game: game),
            ],
          ),
      ],
    );
  }
}

void _openSplit(BuildContext context, String gameId) {
  context.goNamed(Routes.gameSplit, pathParameters: {'gameId': gameId});
}

/// Atalho de um total (design-system.md, 7.9): o rótulo com a seta, o valor
/// em Bebas Neue e a linha de apoio. Tocar rola até a seção.
class _TotalShortcut extends StatelessWidget {
  const _TotalShortcut({
    required this.label,
    required this.cents,
    required this.support,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int cents;
  final String support;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBlock = VoleiColors.of(context).onBlock;
    return MergeSemantics(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: onBlock,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Symbols.chevron_right, size: 20, color: onBlock),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCents(cents),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 34,
                      color: onBlock,
                    ),
                  ),
                ),
                Text(
                  support,
                  style: theme.textTheme.bodyMedium?.copyWith(color: onBlock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de valor (design-system.md, 7.13): o valor e o selo à direita,
/// encolhendo juntos com a fonte grande, sem cortar.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.cents,
    required this.onTap,
    this.badge,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final int cents;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                          formatCents(cents),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 24,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(height: 4),
                          badge!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _gameTitle(DateTime startsAt, String location) =>
    '${formatShortDate(startsAt)} · $location';

/// Um valor a pagar: o jogo, "Para {recebedor}" e, se for multa, o tipo.
class _ToPayRow extends ConsumerWidget {
  const _ToPayRow({required this.line});

  final ChargeLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = line.receiverPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return _AmountRow(
      key: Key('toPay-${line.gameId}'),
      leading: VoleiAvatar(
        id: line.receiverId,
        name: line.receiverName,
        imageUrl: url,
      ),
      title: _gameTitle(line.startsAt, line.locationName),
      subtitle: [
        l10n.splitOwedTo(line.receiverName),
        if (line.kind.isPenalty) chargeKindLabel(l10n, line.kind),
      ].join(' · '),
      cents: line.amountCents,
      badge: ChargeStatusBadge(status: line.status),
      onTap: () =>
          context.goNamed(Routes.charge, pathParameters: {'chargeId': line.id}),
    );
  }
}

/// Um comprovante a conferir: quem pagou, o jogo, o valor e o selo Em
/// análise. Tocar abre o comprovante.
class _ToReviewRow extends ConsumerWidget {
  const _ToReviewRow({required this.line});

  final ReviewLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = line.payerPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    return _AmountRow(
      key: Key('toReview-${line.receiptId}'),
      leading: VoleiAvatar(
        id: line.payerId,
        name: line.payerName,
        imageUrl: url,
      ),
      title: line.payerName,
      subtitle: _gameTitle(line.startsAt, line.locationName),
      cents: line.amountCents,
      badge: const ChargeStatusBadge(status: ChargeStatus.underReview),
      // A tela do comprovante relê a aba ao voltar.
      onTap: () => context.pushNamed(
        Routes.receipt,
        pathParameters: {'receiptId': line.receiptId},
      ),
    );
  }
}

/// Um jogo a receber: quantas pessoas devem e a soma.
class _ToReceiveRow extends StatelessWidget {
  const _ToReceiveRow({required this.game});

  final GameToReceive game;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = VoleiColors.of(context);
    return _AmountRow(
      key: Key('toReceive-${game.gameId}'),
      leading: IconSquare(
        icon: Symbols.groups,
        size: 44,
        background: colors.receive,
        foreground: colors.onBlock,
      ),
      title: _gameTitle(game.startsAt, game.locationName),
      subtitle: l10n.chargesPeopleCount(game.payerIds.length),
      cents: game.amountCents,
      onTap: () => _openSplit(context, game.gameId),
    );
  }
}
