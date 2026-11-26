import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/format/file_size.dart';
import '../../../core/receipt_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../games/domain/charge_models.dart';
import '../data/receipts_repository.dart';
import '../domain/receipt_models.dart';

/// Abre Enviar comprovante sobre o valor a pagar (docs/ui/telas.md, 9.3).
/// Devolve o texto do `SnackBar` que a tela mostra ao fechar, quando houver.
/// A tela relê o valor em qualquer caso.
///
/// O arrasto fica desligado e a alça é só desenho: durante a leitura a sheet
/// não fecha (RN86), e o arrasto da alça fecharia sem passar pelo
/// `PopScope`.
Future<String?> showReceiptSendSheet(
  BuildContext context,
  ChargeDetail charge,
) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  backgroundColor: Theme.of(context).colorScheme.surface,
  barrierColor: const Color.fromRGBO(5, 10, 25, .72),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => ReceiptSendSheet(charge: charge),
);

enum _Step { choose, confirm, reading, result }

/// Os quatro passos: escolher, conferir, lendo e resultado.
class ReceiptSendSheet extends ConsumerStatefulWidget {
  const ReceiptSendSheet({required this.charge, super.key});

  final ChargeDetail charge;

  @override
  ConsumerState<ReceiptSendSheet> createState() => _ReceiptSendSheetState();
}

class _ReceiptSendSheetState extends ConsumerState<ReceiptSendSheet> {
  _Step _step = _Step.choose;
  ReceiptFile? _file;

  /// O erro do passo 1: tipo, tamanho ou o arquivo recusado pelo servidor.
  String? _chooseError;

  /// O envio ao bucket falhou: o passo 2 mostra o erro e **Tentar de novo**.
  bool _uploadFailed = false;
  ReceiptResult? _result;

  Future<void> _pick(Future<PickedFile?> Function() pick) async {
    final l10n = AppLocalizations.of(context);
    final PickedFile? picked;
    try {
      picked = await pick();
    } on Object {
      // O seletor do sistema falhou: a pessoa escolhe de novo.
      return;
    }
    if (picked == null || !mounted) return;
    try {
      final file = ReceiptFile.fromPicked(picked);
      setState(() {
        _file = file;
        _chooseError = null;
        _uploadFailed = false;
        _step = _Step.confirm;
      });
    } on AppException catch (error) {
      setState(() => _chooseError = errorText(l10n, error.code));
    }
  }

  Future<void> _send() async {
    final file = _file!;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(receiptsRepositoryProvider);
    final chargeId = widget.charge.id;
    setState(() {
      _step = _Step.reading;
      _uploadFailed = false;
    });

    // Um nome novo a cada envio (telas.md, 9.3).
    final path = receiptStoragePath(chargeId, file.extension);
    try {
      await repository.upload(
        path: path,
        bytes: file.bytes,
        mimeType: file.mimeType,
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _step = _Step.confirm;
        _uploadFailed = true;
      });
      return;
    }

    try {
      final result = await repository.process(
        chargeId: chargeId,
        storagePath: path,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.result;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      switch (error.code) {
        // O arquivo não serve: escolher outro, no passo 1.
        case ErrorCode.receiptFileNotFound ||
            ErrorCode.receiptTypeInvalid ||
            ErrorCode.receiptTooLarge:
          setState(() {
            _file = null;
            _chooseError = errorText(l10n, error.code);
            _step = _Step.choose;
          });
        // Sem resposta, o servidor pode ter gravado: a tela relê.
        case ErrorCode.noConnection:
          Navigator.of(context).pop(l10n.receiptResultUnknown);
        default:
          Navigator.of(context).pop(errorText(l10n, error.code));
      }
    }
  }

  void _restart() => setState(() {
    _file = null;
    _result = null;
    _chooseError = null;
    _uploadFailed = false;
    _step = _Step.choose;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reading = _step == _Step.reading;

    final content = switch (_step) {
      _Step.choose => _choose(l10n),
      _Step.confirm => _confirm(l10n),
      _Step.reading => _reading(l10n),
      _Step.result => _resultView(l10n),
    };

    return PopScope(
      // Durante a leitura, nem o voltar nem o toque fora fecham (RN86).
      canPop: !reading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Handle(),
            if (_step != _Step.result) ...[
              Text(l10n.receiptSend, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
            ],
            ...content,
          ],
        ),
      ),
    );
  }

  List<Widget> _choose(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final picker = ref.read(receiptPickerProvider);
    final error = _chooseError;
    return [
      Text(l10n.receiptSendBody, style: theme.textTheme.bodyLarge),
      if (widget.charge.autoReadsUsed >= 3) ...[
        const SizedBox(height: 16),
        InlineNotice(
          icon: Symbols.info,
          color: VoleiColors.of(context).split,
          text: l10n.receiptNoMoreReads(widget.charge.receiverName),
        ),
      ],
      const SizedBox(height: 8),
      SheetOptions(
        options: [
          SheetOption(
            icon: Symbols.image,
            label: l10n.receiptPickImage,
            onTap: () => _pick(picker.pickImage),
          ),
          SheetOption(
            icon: Symbols.picture_as_pdf,
            label: l10n.receiptPickPdf,
            onTap: () => _pick(picker.pickPdf),
          ),
        ],
      ),
      if (error != null) FieldErrorText(error),
    ];
  }

  List<Widget> _confirm(AppLocalizations l10n) => [
    _FilePreview(file: _file!),
    if (_uploadFailed) FieldErrorText(l10n.receiptUploadFailed),
    const SizedBox(height: 24),
    PrimaryButton(
      label: _uploadFailed ? l10n.commonTryAgain : l10n.receiptSendAction,
      onPressed: _send,
    ),
    const SizedBox(height: 8),
    TextButton(onPressed: _restart, child: Text(l10n.receiptPickOther)),
  ];

  List<Widget> _reading(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return [
      _FilePreview(file: _file!),
      const SizedBox(height: 24),
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: 16),
      Semantics(
        liveRegion: true,
        child: Text(
          l10n.receiptReading,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    ];
  }

  List<Widget> _resultView(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final result = _result!;
    final (icon, color, onIcon, text) = switch (result.status) {
      ReceiptStatus.approved => (
        Symbols.check,
        colors.receive,
        colors.onBlock,
        l10n.receiptApproved,
      ),
      ReceiptStatus.underReview => (
        Symbols.hourglass_top,
        colors.split,
        colors.onBlock,
        l10n.receiptUnderReview(widget.charge.receiverName),
      ),
      ReceiptStatus.rejected => (
        Symbols.block,
        colors.destructive,
        Colors.white,
        l10n.receiptDuplicate,
      ),
    };
    final done = result.status != ReceiptStatus.rejected;
    return [
      const SizedBox(height: 16),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: ExcludeSemantics(child: Icon(icon, size: 48, color: onIcon)),
        ),
      ),
      const SizedBox(height: 24),
      Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: 24),
      if (done)
        PrimaryButton(
          label: l10n.receiptDone,
          onPressed: () => Navigator.of(context).pop(),
        )
      else ...[
        PrimaryButton(label: l10n.receiptSendOther, onPressed: _restart),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.receiptClose),
        ),
      ],
    ];
  }
}

/// A alça da sheet (design-system.md, 7.15), só desenho.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant
                .withValues(alpha: .4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// A miniatura da imagem, sem cortar o comprovante, ou o ícone de PDF com o
/// nome e o tamanho (telas-fatia-6.md, Componentes novos).
class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.file});

  final ReceiptFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (file.isPdf) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const IconSquare(icon: Symbols.picture_as_pdf, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name, style: theme.textTheme.titleMedium),
                  Text(
                    formatFileSize(file.size),
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
    return Container(
      key: const Key('receiptThumbnail'),
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          file.bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Icon(
              Symbols.receipt_long,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
