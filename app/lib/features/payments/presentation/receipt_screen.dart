import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
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
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../../games/presentation/games_providers.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt_models.dart';
import 'receipt_text.dart';

/// O comprovante, relido ao abrir, ao puxar para baixo e depois de um erro
/// (docs/ui/telas.md, seção 9).
final receiptProvider = FutureProvider.autoDispose
    .family<ReceiptDetail, String>(
      (ref, receiptId) =>
          ref.watch(receiptsRepositoryProvider).fetchReceipt(receiptId),
    );

/// A URL assinada de 10 minutos, pedida ao abrir (telas.md, 9.4).
final receiptFileUrlProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, path) => ref.watch(receiptsRepositoryProvider).fileUrl(path),
    );

/// Comprovante (RF83, RF86, RF87; docs/ui/telas.md, 9.4; receipt.png,
/// receipt-pagador.png e receipt-recusar.png). Só para o pagador e o
/// recebedor do comprovante, na aba Cobranças. O recebedor vê a Conferência
/// e, com o comprovante Em análise, aprova ou recusa.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({required this.receiptId, super.key});

  final String receiptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final receipt = ref.watch(receiptProvider(receiptId));

    // Ao voltar, a tela de origem relê (telas.md, seção 9).
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _refreshOrigins(ref);
      },
      child: Scaffold(
        appBar: InnerAppBar(
          title: l10n.receiptTitle,
          onBack: () => _back(context),
        ),
        body: switch (receipt) {
          AsyncValue(:final value?) => Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(receiptProvider(receiptId).future),
                  child: _ReceiptBody(receipt: value),
                ),
              ),
              if (value.viewerIsReceiver &&
                  value.status == ReceiptStatus.underReview)
                _DecisionFooter(receipt: value),
            ],
          ),
          AsyncError(:final error) => ErrorStateView(
            error: error,
            onRetry: () => ref.invalidate(receiptProvider(receiptId)),
          ),
          _ => const LoadingState(),
        },
      ),
    );
  }
}

/// Cobranças, o valor a pagar e o Rateio, de onde o comprovante abre: quem
/// estiver na pilha relê.
void _refreshOrigins(WidgetRef ref) {
  ref
    ..invalidate(myChargesProvider)
    ..invalidate(chargeProvider)
    ..invalidate(gameSplitProvider);
}

void _back(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(Routes.charges);
  }
}

class _ReceiptBody extends ConsumerWidget {
  const _ReceiptBody({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final decision = _decisionText(l10n, receipt);

    // Uma tela curta: tudo montado, também o que está abaixo da imagem.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(receipt: receipt),
          const SizedBox(height: 16),
          _FileBlock(receipt: receipt),
          if (decision != null) ...[
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, line) in decision.indexed)
                    Text(
                      line,
                      style: index == 0
                          ? theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            )
                          : theme.textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          ],
          if (receipt.viewerIsReceiver) ...[
            const SizedBox(height: 24),
            _CheckBlock(receipt: receipt),
          ],
        ],
      ),
    );
  }
}

/// As linhas da decisão (telas.md, 9.4, bloco 5): a frase e, se houver, a
/// observação. Nulo com o comprovante Em análise.
List<String>? _decisionText(AppLocalizations l10n, ReceiptDetail receipt) {
  final decidedAt = receipt.decidedAt;
  if (receipt.status == ReceiptStatus.underReview || decidedAt == null) {
    return null;
  }
  final date = formatShortDate(decidedAt);
  final name = receipt.decidedByName;
  if (receipt.status == ReceiptStatus.approved) {
    return [
      name == null
          ? l10n.receiptDecidedAuto(date)
          : l10n.receiptDecidedApproved(name, date),
    ];
  }
  if (receipt.rejectionReason == ReceiptRejectionReason.duplicateTransaction) {
    return [l10n.receiptRejectedDuplicate, date];
  }
  final note = receipt.receiverNote;
  return [
    l10n.receiptDecidedRejected(name ?? receipt.receiverName, date),
    if (note != null) l10n.receiptNoteQuoted(note),
  ];
}

/// Card `surface` de raio 22 (design-system.md, 7.4).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

/// Para o recebedor, quem pagou; para o pagador, "Para {recebedor}". O jogo,
/// o valor e o selo do comprovante.
class _Header extends ConsumerWidget {
  const _Header({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final receiver = receipt.viewerIsReceiver;
    final personId = receiver ? receipt.payerId : receipt.receiverId;
    final personName = receiver ? receipt.payerName : receipt.receiverName;
    final path = receiver ? receipt.payerPhotoPath : receipt.receiverPhotoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;

    return _Card(
      child: Row(
        children: [
          VoleiAvatar(id: personId, name: personName, imageUrl: url),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiver ? personName : l10n.splitOwedTo(personName),
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '${formatShortDate(receipt.startsAt)} · '
                  '${receipt.locationName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                    formatCents(receipt.amountCents),
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 4),
                  ReceiptStatusBadge(status: receipt.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O arquivo: a imagem, que abre em tela cheia; **Abrir PDF**; o arquivo
/// apagado; ou a falha da URL assinada, com **Tentar de novo**.
class _FileBlock extends ConsumerWidget {
  const _FileBlock({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final path = receipt.storagePath;
    if (path == null) {
      final deletedAt = receipt.fileDeletedAt;
      return _Card(
        child: Text(
          deletedAt == null
              ? l10n.receiptFileError
              : l10n.receiptFileDeleted(formatShortDate(deletedAt)),
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final url = ref.watch(receiptFileUrlProvider(path));
    return switch (url) {
      AsyncValue(:final value?) =>
        receipt.isPdf
            ? Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Symbols.open_in_new),
                  label: Text(l10n.receiptOpenPdf),
                  onPressed: () =>
                      ref.read(linkOpenerProvider).open(Uri.parse(value)),
                ),
              )
            : _ReceiptImage(url: value),
      AsyncError() => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.receiptFileError, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(receiptFileUrlProvider(path)),
              child: Text(l10n.commonTryAgain),
            ),
          ],
        ),
      ),
      _ => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _ReceiptImage extends StatelessWidget {
  const _ReceiptImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.receiptImageLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('receiptImage'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (context) => _FullScreenImage(url: url),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Center(child: _NetworkImage(url: url)),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.open_in_full,
                      color: theme.colorScheme.onSurface,
                    ),
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

/// A imagem pela URL assinada. Se não carregar, o ícone do comprovante.
class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.contain,
    errorBuilder: (_, _, _) => SizedBox(
      height: 160,
      child: Center(
        child: Icon(
          Symbols.receipt_long,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// A imagem em tela cheia, com zoom.
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Symbols.close),
          tooltip: l10n.receiptClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Semantics(
            label: l10n.receiptTitle,
            image: true,
            child: _NetworkImage(url: url),
          ),
        ),
      ),
    );
  }
}

/// A Conferência, só para o recebedor (telas.md, 9.4, bloco 4).
class _CheckBlock extends StatelessWidget {
  const _CheckBlock({required this.receipt});

  final ReceiptDetail receipt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = receiptCheckView(l10n, receipt);
    final skipped = view.skippedText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.receiptCheckTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (skipped != null)
          _Card(child: Text(skipped, style: theme.textTheme.bodyLarge))
        else ...[
          Text(
            l10n.receiptCheckHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, row) in view.rows.indexed) ...[
                  if (index > 0) const Divider(height: 24),
                  _CheckRow(row: row),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// O rótulo e o selo na primeira linha; embaixo, o esperado e o lido. O
/// TalkBack lê a linha inteira (S89).
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.row});

  final ReceiptCheckRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final support = theme.textTheme.bodyMedium;
    return Semantics(
      label: row.semantics,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(row.label, style: theme.textTheme.titleMedium),
              VoleiBadge(
                label: row.resultLabel,
                tone: switch (row.result) {
                  ReceiptCheckResult.ok => colors.ok,
                  ReceiptCheckResult.fail => colors.bad,
                  ReceiptCheckResult.unread => colors.neutral,
                },
                icon: switch (row.result) {
                  ReceiptCheckResult.ok => Symbols.check,
                  ReceiptCheckResult.fail => Symbols.close,
                  ReceiptCheckResult.unread => null,
                },
              ),
            ],
          ),
          if (row.expected case final expected?) ...[
            const SizedBox(height: 6),
            Text(expected, style: support),
          ],
          if (row.read case final read?) ...[
            const SizedBox(height: 4),
            // O código do Pix distingue letras e números parecidos: nunca
            // Bebas Neue (telas-fatia-6.md, Regras gerais).
            Text(
              read,
              style: row.item == ReceiptCheckItem.transactionId
                  ? support?.copyWith(fontFamily: 'monospace')
                  : support,
            ),
          ],
        ],
      ),
    );
  }
}

/// **Aprovar** e **Recusar**, fixos no pé, só para o recebedor com o
/// comprovante Em análise.
class _DecisionFooter extends ConsumerStatefulWidget {
  const _DecisionFooter({required this.receipt});

  final ReceiptDetail receipt;

  @override
  ConsumerState<_DecisionFooter> createState() => _DecisionFooterState();
}

class _DecisionFooterState extends ConsumerState<_DecisionFooter> {
  bool _busy = false;

  Future<void> _approve() async {
    final l10n = AppLocalizations.of(context);
    final receipt = widget.receipt;
    final confirmed = await confirmAction(
      context,
      title: l10n.receiptApproveTitle,
      body: l10n.receiptApproveBody(formatCents(receipt.amountCents)),
      confirmLabel: l10n.receiptApprove,
    );
    if (!confirmed || !mounted) return;
    await _review(
      () => ref
          .read(receiptsRepositoryProvider)
          .review(receiptId: receipt.id, approve: true),
      l10n.receiptApprovedByYou,
    );
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final receipt = widget.receipt;
    final note = await showVoleiSheet<String>(
      context,
      (context) => _RejectSheet(payerName: receipt.payerName),
    );
    if (note == null || !mounted) return;
    await _review(
      () => ref
          .read(receiptsRepositoryProvider)
          .review(receiptId: receipt.id, approve: false, note: note),
      l10n.receiptRejectedByYou,
    );
  }

  /// Chama `review_receipt`. Com sucesso, o `SnackBar` e volta; com erro, o
  /// `SnackBar`, e a tela relê.
  Future<void> _review(Future<void> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      _refreshOrigins(ref);
      showSnack(context, done);
      _back(context);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
      ref.invalidate(receiptProvider(widget.receipt.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: DestructiveOutlinedButton(
              label: l10n.receiptReject,
              onPressed: _busy ? null : _reject,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: l10n.receiptApprove,
              loading: _busy,
              onPressed: _approve,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sheet de recusa (receipt-recusar.png): a observação, obrigatória e com
/// até 200 caracteres. Devolve o texto sem os espaços das pontas.
class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.payerName});

  final String payerName;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  /// O limite de `review_receipt` (contratos-api.md, seção 6).
  static const _maxLength = 200;

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _controller.text.trim();
    if (note.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).receiptNoteRequired);
      return;
    }
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      // A sheet sobe com o teclado.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.receiptRejectTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            l10n.receiptRejectBody(widget.payerName),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FieldLabel(l10n.receiptNoteLabel),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: _maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: l10n.receiptReject,
            destructive: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
