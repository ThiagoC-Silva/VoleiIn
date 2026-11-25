import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/hero_parts.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/pix_key.dart';
import '../../games/data/games_repository.dart';
import '../../games/domain/charge_models.dart';
import '../../games/presentation/game_badges.dart';
import '../../games/presentation/games_providers.dart';
import '../../games/presentation/pix_text.dart';
import '../../games/presentation/split_text.dart';

/// O valor a pagar, relido ao abrir e ao puxar para baixo (telas.md, seção 9).
final chargeProvider = FutureProvider.autoDispose.family<ChargeDetail, String>(
  (ref, chargeId) => ref.watch(gamesRepositoryProvider).fetchCharge(chargeId),
);

/// Valor a pagar (RF77; docs/ui/telas.md, 9.2; charge.png, charge-analise.png
/// e charge-pago.png): quanto e a quem pagar, com a chave Pix do recebedor do
/// valor. Só para o pagador, na aba Cobranças. Os comprovantes e **Enviar
/// comprovante** chegam na etapa B.
class ChargeScreen extends ConsumerWidget {
  const ChargeScreen({required this.chargeId, super.key});

  final String chargeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = ref.watch(chargeProvider(chargeId));

    // Ao voltar, Cobranças relê (telas.md, seção 9).
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(myChargesProvider);
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: AppLocalizations.of(context).chargeTitle,
        child: Scaffold(
          body: switch (charge) {
            AsyncValue(:final value?) => RefreshIndicator(
              onRefresh: () => ref.refresh(chargeProvider(chargeId).future),
              child: _ChargeBody(charge: value),
            ),
            AsyncError(:final error) => SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BackOnly(),
                  Expanded(
                    child: ErrorStateView(
                      error: error,
                      onRetry: () => ref.invalidate(chargeProvider(chargeId)),
                    ),
                  ),
                ],
              ),
            ),
            _ => const LoadingState(),
          },
        ),
      ),
    );
  }
}

/// Só o voltar, nos estados sem valor (erro, não encontrado).
class _BackOnly extends StatelessWidget {
  const _BackOnly();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: HeroCircleButton(
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
    context.goNamed(Routes.charges);
  }
}

class _ChargeBody extends StatelessWidget {
  const _ChargeBody({required this.charge});

  final ChargeDetail charge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final paidAt = charge.paidAt;
    final paidDate = paidAt == null ? '' : formatShortDate(paidAt);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChargeHero(charge: charge),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: switch (charge.status) {
                ChargeStatus.pending => [_PayTo(charge: charge)],
                ChargeStatus.underReview => [
                  _PayTo(charge: charge),
                  const SizedBox(height: 16),
                  InlineNotice(
                    icon: Symbols.hourglass_top,
                    color: colors.split,
                    text: l10n.chargeUnderReviewNotice(charge.receiverName),
                  ),
                ],
                ChargeStatus.paid => [
                  InlineNotice(
                    icon: Symbols.check_circle,
                    color: colors.receive,
                    text: charge.paidVia == PaymentMethod.receipt
                        ? l10n.chargePaidReceipt(paidDate)
                        : l10n.chargePaidManual(charge.receiverName, paidDate),
                  ),
                ],
                ChargeStatus.waived => [
                  InlineNotice(
                    icon: Symbols.money_off,
                    color: theme.colorScheme.surfaceContainerHigh,
                    iconColor: theme.colorScheme.onSurface,
                    text: chargeWaivedLabel(l10n, charge.waiveReason),
                  ),
                ],
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Topo colorido do valor (design-system.md, 7.8): `owe` Pendente, `split` Em
/// análise, `receive` Pago e `surfaceHigh` Isento.
class _ChargeHero extends StatelessWidget {
  const _ChargeHero({required this.charge});

  final ChargeDetail charge;

  static const _bottomRadius = BorderRadius.vertical(
    bottom: Radius.circular(32),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final waived = charge.status == ChargeStatus.waived;
    final background = switch (charge.status) {
      ChargeStatus.pending => colors.owe,
      ChargeStatus.underReview => colors.split,
      ChargeStatus.paid => colors.receive,
      ChargeStatus.waived => theme.colorScheme.surfaceContainerHigh,
    };
    final foreground = waived ? theme.colorScheme.onSurface : colors.onBlock;
    final buttonBackground = waived
        ? theme.colorScheme.surface
        : colors.onBlock;
    final strong = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: foreground,
    );

    return ClipRRect(
      borderRadius: _bottomRadius,
      child: Stack(
        children: [
          Container(
            key: const Key('chargeHero'),
            width: double.infinity,
            decoration: BoxDecoration(color: background),
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 12,
              24,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroCircleButton(
                  icon: Symbols.arrow_back,
                  tooltip: l10n.commonBack,
                  background: buttonBackground,
                  foreground: waived ? foreground : background,
                  onPressed: () => _back(context),
                ),
                const SizedBox(height: 16),
                GroupPill(
                  label: charge.groupName ?? l10n.gameStandalone,
                  standalone: charge.groupName == null,
                  background: buttonBackground,
                  foreground: theme.colorScheme.onSurface,
                ),
                const SizedBox(height: 12),
                Text(
                  '${formatShortDate(charge.startsAt)} · '
                  '${charge.locationName}',
                  style: strong,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCents(charge.amountCents),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chargeKindLabel(l10n, charge.kind),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 8),
                ChargeStatusBadge(status: charge.status, onBlock: true),
              ],
            ),
          ),
          // O círculo vazado (design-system.md, seção 6), só enfeite.
          const Positioned(
            right: -48,
            top: 72,
            child: IgnorePointer(
              child: SizedBox.square(
                dimension: 190,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: Color.fromRGBO(25, 40, 83, .08),
                        width: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **Pagar para**: o recebedor do valor (RN32), a chave Pix com **Copiar
/// chave** e a dica do valor exato (RN88a).
class _PayTo extends ConsumerWidget {
  const _PayTo({required this.charge});

  final ChargeDetail charge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurfaceVariant;
    final key = charge.receiverPixKey;
    final type = charge.receiverPixKeyType;
    final path = charge.receiverPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.chargePayTo, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
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
                  VoleiAvatar(
                    id: charge.receiverId,
                    name: charge.receiverName,
                    imageUrl: url,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.receiverName,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (key != null && type != null)
                          Text(
                            l10n.profilePixSummary(
                              pixTypeLabel(l10n, type),
                              formatPixKey(type, key),
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (key != null && type != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Symbols.content_copy),
                    label: Text(l10n.gamePixCopy),
                    onPressed: () async {
                      // A chave sem formatação, como o Pix a recebe.
                      await Clipboard.setData(ClipboardData(text: key));
                      if (context.mounted) {
                        showSnack(context, l10n.gamePixCopied);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(Symbols.info, size: 20, color: soft),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.chargePayExact,
                      style: theme.textTheme.bodyMedium?.copyWith(color: soft),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
