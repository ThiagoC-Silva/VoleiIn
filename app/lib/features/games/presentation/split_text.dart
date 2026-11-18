import '../../../core/format/money.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/charge_models.dart';

/// O valor por conta do recebedor (docs/ui/telas.md, seção 8; U13). Negativo
/// pelo arredondamento (R04), vira a frase `splitReceiverExtra`, com o valor
/// absoluto: `formatCents` só recebe valores ≥ 0.
String receiverCoveredText(AppLocalizations l10n, int cents, String name) =>
    cents < 0
    ? l10n.splitReceiverExtra(name, formatCents(-cents))
    : formatCents(cents);

/// Rótulo do `kind` (telas.md, seção 8).
String chargeKindLabel(AppLocalizations l10n, ChargeKind kind) =>
    switch (kind) {
      ChargeKind.share => l10n.chargeKindShare,
      ChargeKind.absencePenalty => l10n.chargeKindAbsence,
      ChargeKind.lateCancellationPenalty => l10n.chargeKindLateCancellation,
    };

/// Texto do selo do status (design-system.md, seção 4).
String chargeStatusLabel(AppLocalizations l10n, ChargeStatus status) =>
    switch (status) {
      ChargeStatus.pending => l10n.chargeStatusPending,
      ChargeStatus.underReview => l10n.chargeStatusUnderReview,
      ChargeStatus.paid => l10n.chargeStatusPaid,
      ChargeStatus.waived => l10n.chargeStatusWaived,
    };

/// Motivo do Isento.
String chargeWaivedLabel(AppLocalizations l10n, ChargeWaiveReason? reason) =>
    switch (reason) {
      ChargeWaiveReason.receiverChange => l10n.chargeWaivedReceiverChange,
      _ => l10n.chargeWaivedManual,
    };
