import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/format/date_time.dart';
import '../../../core/format/money.dart';
import '../../../core/format/money_input.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/games_repository.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';
import 'game_controllers.dart';
import 'games_providers.dart';
import 'split_text.dart';

/// Concluir jogo (RF40, RF41; docs/ui/telas.md, 8.2; gameComplete.png,
/// gameComplete-vagas.png e gameComplete-confirmar.png). Fora das abas. O
/// resumo é sempre o do servidor (`preview_complete_game`): o app não calcula
/// nada. As faltas (RF60, etapa B) são caixas de seleção, com as saídas
/// depois do início já marcadas (RN47) e sem o recebedor (RF63).
class GameCompleteScreen extends ConsumerWidget {
  const GameCompleteScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(gameDetailProvider(gameId));
    void retry() => ref.invalidate(gameDetailProvider(gameId));

    return Scaffold(
      appBar: InnerAppBar(title: l10n.gameComplete),
      body: switch (game) {
        // Só admins do jogo, com o jogo Aberto ou Confirmado (telas.md, 8.2).
        AsyncValue(:final value?)
            when !value.isAdmin || !value.status.isActive =>
          ErrorStateView(
            error: const AppException(ErrorCode.notFound),
            onRetry: retry,
          ),
        AsyncValue(:final value?) => _CompleteForm(game: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: retry,
        ),
        _ => const LoadingState(),
      },
    );
  }
}

/// Os parâmetros de um *preview*: o de `complete_game` tem de ser igual.
typedef _Params = ({int? totalCents, List<String> absentUserIds});

class _CompleteForm extends ConsumerStatefulWidget {
  const _CompleteForm({required this.game});

  final GameDetail game;

  @override
  ConsumerState<_CompleteForm> createState() => _CompleteFormState();
}

class _CompleteFormState extends ConsumerState<_CompleteForm> {
  static const _debounce = Duration(milliseconds: 400);

  late final _total = TextEditingController(
    text: formatCentsInput(widget.game.totalCents),
  );
  Timer? _timer;

  /// Cada *preview* ganha um número; só a resposta do último vale.
  int _request = 0;
  CompletionPreview? _preview;
  _Params? _previewParams;
  Object? _previewError;
  bool _loading = true;

  /// As caixas marcadas. Começam com as faltas de saída após o início (RN47).
  late Set<String> _absent = {
    for (final person in _candidates(widget.game))
      if (person.status == ParticipantStatus.leftAfterStart && person.absent)
        person.userId,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPreview());
  }

  /// O jogo relido (Realtime, ou depois de uma falta recusada): as marcas de
  /// quem saiu da lista caem, quem saiu depois do início entra marcado, e o
  /// *preview* é refeito com a lista nova.
  @override
  void didUpdateWidget(_CompleteForm old) {
    super.didUpdateWidget(old);
    if (old.game == widget.game) return;
    final before = {for (final p in _candidates(old.game)) p.userId};
    _absent = {
      for (final person in _candidates(widget.game))
        if (_absent.contains(person.userId) ||
            (!before.contains(person.userId) &&
                person.status == ParticipantStatus.leftAfterStart &&
                person.absent))
          person.userId,
    };
    _runPreview();
  }

  /// As passagens que podem levar falta: `active` e `left_after_start`, por
  /// ordem de `joined_at`, sem o recebedor (telas.md, 8.2; RF63).
  static List<GameParticipant> _candidates(GameDetail game) => [
    for (final person in game.participants)
      if (person.status.takesSlot && person.userId != game.receiverId) person,
  ]..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

  @override
  void dispose() {
    _timer?.cancel();
    _total.dispose();
    super.dispose();
  }

  int? get _totalCents {
    final cents = parseMoneyInput(_total.text);
    return cents == null || cents <= 0 ? null : cents;
  }

  /// A lista completa das caixas marcadas, na ordem da lista
  /// (contratos-api.md, `complete_game`).
  List<String> get _absentUserIds => [
    for (final person in _candidates(widget.game))
      if (_absent.contains(person.userId)) person.userId,
  ];

  /// Nulo quando o total não mudou (contratos-api.md, `complete_game`).
  _Params? get _params {
    final cents = _totalCents;
    if (cents == null) return null;
    return (
      totalCents: cents == widget.game.totalCents ? null : cents,
      absentUserIds: _absentUserIds,
    );
  }

  bool get _ready {
    final params = _params;
    final last = _previewParams;
    return !_loading &&
        _preview != null &&
        params != null &&
        last != null &&
        params.totalCents == last.totalCents &&
        _sameIds(params.absentUserIds, last.absentUserIds);
  }

  void _onTotalChanged(String _) => _scheduleRefresh();

  void _toggleAbsent(String userId) {
    setState(() {
      if (!_absent.remove(userId)) _absent.add(userId);
    });
    _scheduleRefresh();
  }

  /// Um novo *preview* 400 ms depois da última mudança, com o carregando no
  /// lugar dos números enquanto isso.
  void _scheduleRefresh() {
    _timer?.cancel();
    _request++;
    setState(() {
      _loading = _params != null;
      _preview = null;
      _previewError = null;
    });
    if (_params != null) _timer = Timer(_debounce, _runPreview);
  }

  Future<void> _runPreview() async {
    final params = _params;
    if (params == null || !mounted) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _previewError = null;
    });
    try {
      final preview = await ref
          .read(gamesRepositoryProvider)
          .previewCompleteGame(
            gameId: widget.game.id,
            totalCents: params.totalCents,
            absentUserIds: params.absentUserIds,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _preview = preview;
        _previewParams = params;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      final failure = toAppException(error);
      if (_leavesScreen(failure)) {
        _leave(failure);
        return;
      }
      setState(() {
        _previewError = failure;
        _loading = false;
      });
    }
  }

  /// `GAME_NOT_OPEN`, `GAME_NOT_ENDED` e `NOT_GAME_ADMIN`: volta ao detalhe
  /// (telas.md, seção 8).
  static bool _leavesScreen(AppException error) =>
      error.code == ErrorCode.gameNotOpen ||
      error.code == ErrorCode.gameNotEnded ||
      error.code == ErrorCode.notGameAdmin;

  void _leave(AppException error) {
    showErrorSnack(context, error);
    ref.invalidate(gameDetailProvider(widget.game.id));
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.game, pathParameters: {'gameId': widget.game.id});
    }
  }

  Future<void> _complete() async {
    final l10n = AppLocalizations.of(context);
    final params = _previewParams!;
    final confirmed = await confirmAction(
      context,
      title: l10n.completeConfirmTitle,
      body: l10n.completeConfirmBody,
      confirmLabel: l10n.completeConfirmAction,
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(gameCompletionControllerProvider.notifier)
        .complete(
          gameId: widget.game.id,
          totalCents: params.totalCents,
          absentUserIds: params.absentUserIds,
        );
    if (!mounted) return;
    if (error == null) {
      showSnack(context, l10n.gameCompleted);
      // A tela vira o Rateio, e o voltar leva ao detalhe (telas.md, 8.2).
      context.goNamed(
        Routes.gameSplit,
        pathParameters: {'gameId': widget.game.id},
      );
      return;
    }
    if (_leavesScreen(error)) {
      _leave(error);
      return;
    }
    showErrorSnack(context, error);
    // A lista mudou: a tela relê o jogo e refaz o *preview*.
    // O controller já pediu a releitura do jogo; o didUpdateWidget refaz o
    // *preview* quando ela chega, e este cobre a lista que não mudou.
    if (error.hasCode(ErrorCode.absentNotParticipant) ||
        error.hasCode(ErrorCode.receiverCannotBeAbsent)) {
      unawaited(_runPreview());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final game = widget.game;
    final busy = ref.watch(gameCompletionControllerProvider).isLoading;
    final soft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final totalMissing = _totalCents == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GameLine(
                  text: [
                    formatShortDate(game.startsAt),
                    l10n.gameTimeRange(
                      formatTime(game.startsAt),
                      formatTime(game.endsAt),
                    ),
                    game.locationName,
                  ].join(' · '),
                ),
                const SizedBox(height: 20),
                LabeledField(
                  key: const Key('completeTotalField'),
                  label: l10n.gameTotalLabel,
                  controller: _total,
                  enabled: !busy,
                  prefixText: currencySymbol,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [MoneyInputFormatter()],
                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
                  onChanged: _onTotalChanged,
                  forceErrorText: totalMissing ? l10n.gameTotalRequired : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.completeTotalHint, style: soft),
                const SizedBox(height: 24),
                Text(
                  l10n.completeAbsentTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (_candidates(game).isNotEmpty)
                  ListCard(
                    children: [
                      for (final person in _candidates(game))
                        _AbsentRow(
                          key: Key('absent-${person.userId}'),
                          person: person,
                          checked: _absent.contains(person.userId),
                          enabled: !busy,
                          onToggle: () => _toggleAbsent(person.userId),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(l10n.completeReceiverNoAbsence, style: soft),
                const SizedBox(height: 24),
                Text(
                  l10n.completeSummaryTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!totalMissing)
                  _Summary(
                    game: game,
                    totalCents: _totalCents!,
                    preview: _loading ? null : _preview,
                    error: _loading ? null : _previewError,
                    onRetry: _runPreview,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: PrimaryButton(
            label: l10n.gameComplete,
            loading: busy,
            onPressed: _ready ? _complete : null,
          ),
        ),
      ],
    );
  }
}

/// Linha de falta (gameComplete.png): avatar, nome, "Saiu às {hora}" para
/// quem saiu depois do início, e a caixa à direita. A linha inteira marca e
/// desmarca, e o TalkBack lê `completeAbsentLabel`.
class _AbsentRow extends ConsumerWidget {
  const _AbsentRow({
    required this.person,
    required this.checked,
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  final GameParticipant person;
  final bool checked;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final path = person.photoPath;
    final url = path == null
        ? null
        : ref.watch(gameAvatarUrlProvider(path)).value;
    final leftAt = person.status == ParticipantStatus.leftAfterStart
        ? person.leftAt
        : null;
    final note = leftAt == null
        ? null
        : l10n.completeLeftAt(formatTime(leftAt));
    final tap = enabled ? onToggle : null;

    return Semantics(
      label: l10n.completeAbsentLabel(person.displayName),
      value: note,
      checked: checked,
      enabled: enabled,
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                VoleiAvatar(
                  id: person.userId,
                  name: person.displayName,
                  imageUrl: url,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: checked,
                  onChanged: enabled ? (_) => onToggle() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameIds(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

/// A linha com o ícone do calendário: data, horário e local.
class _GameLine extends StatelessWidget {
  const _GameLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.calendar_month, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// O bloco de resumo do rateio (gameComplete.png): a parte por vaga em
/// `split`, o a receber e o por conta do recebedor, com as linhas de apoio.
/// Sem *preview* para os valores da tela, o indicador de carregando; com a
/// falha, o erro com Tentar de novo.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.game,
    required this.totalCents,
    required this.preview,
    required this.error,
    required this.onRetry,
  });

  final GameDetail game;
  final int totalCents;
  final CompletionPreview? preview;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = VoleiColors.of(context);
    final failure = error;
    final result = preview;

    Widget body;
    if (failure != null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              errorTextFor(l10n, failure),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.commonTryAgain),
            ),
          ],
        ),
      );
    } else if (result == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final soft = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      final covered = result.receiverCoveredCents;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: colors.split,
              borderRadius: BorderRadius.circular(18),
            ),
            child: _SummaryRow(
              label: l10n.gameSharePerSlot,
              caption: l10n.completeShareFormula(
                formatCents(totalCents),
                '${game.slotLimit}',
              ),
              value: formatCents(result.shareCents),
              color: colors.onBlock,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
            child: _SummaryRow(
              label: l10n.completeToReceive,
              value: formatCents(result.totalToReceiveCents),
              color: theme.colorScheme.onSurface,
            ),
          ),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            // Negativo: a frase no lugar do valor (R04).
            child: covered < 0
                ? Text(
                    receiverCoveredText(l10n, covered, game.receiverName),
                    style: theme.textTheme.bodyLarge,
                  )
                : _SummaryRow(
                    label: l10n.splitReceiverCovers(game.receiverName),
                    value: receiverCoveredText(
                      l10n,
                      covered,
                      game.receiverName,
                    ),
                    color: theme.colorScheme.onSurface,
                  ),
          ),
          if (result.penaltiesExempted > 0) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.info,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.completeExemptedCount(result.penaltiesExempted),
                    style: soft,
                  ),
                ),
              ],
            ),
          ],
          if (result.uncoveredSlots > 0) ...[
            const SizedBox(height: 12),
            InlineNotice(
              icon: Symbols.event_seat,
              color: colors.owe,
              text: l10n.completeUncoveredWarning(
                result.uncoveredSlots,
                formatCents(covered < 0 ? 0 : covered),
                game.receiverName,
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: body,
    );
  }
}

/// Rótulo à esquerda, com a legenda, e o valor em Bebas Neue à direita.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.caption,
  });

  final String label;
  final String value;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = caption;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: 30,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
