import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/clock.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/game_models.dart';
import 'game_controllers.dart';
import 'game_form.dart';
import 'games_providers.dart';

/// Editar jogo (RF36, RF52, RF53; docs/ui/telas.md, 7.4; gameEdit.png). Só
/// para admins do jogo, antes do início. Cobre a barra inferior. Tudo é
/// gravado junto, no Salvar.
class GameEditScreen extends ConsumerWidget {
  const GameEditScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(gameDetailProvider(gameId));
    final now = ref.watch(clockProvider)();
    void retry() => ref.invalidate(gameDetailProvider(gameId));

    return Scaffold(
      appBar: InnerAppBar(title: l10n.gameEdit),
      body: switch (game) {
        // Quem não é admin do jogo: "não encontrado" (telas.md, seção 7).
        AsyncValue(:final value?) when !value.isAdmin => ErrorStateView(
          error: const AppException(ErrorCode.notFound),
          onRetry: retry,
        ),
        AsyncValue(:final value?) when !value.status.isActive => EmptyState(
          icon: Symbols.lock,
          title: errorText(l10n, ErrorCode.gameNotOpen),
          body: '',
        ),
        // Pelo relógio do aparelho, só para mostrar: o servidor confere.
        AsyncValue(:final value?) when !now.isBefore(value.startsAt) =>
          EmptyState(icon: Symbols.lock, title: l10n.gameEditStarted, body: ''),
        AsyncValue(:final value?) => _EditForm(game: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: retry,
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.game});

  /// O jogo relido do servidor. O formulário nasce com a primeira leitura;
  /// as seguintes (Realtime, ou depois de um erro) só mudam as ocupadas.
  final GameDetail game;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final GameFormData _data = GameFormData.fromGame(widget.game);
  late final GameDetail _original = widget.game;
  bool _showErrors = false;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _showErrors = true);
    final textValid = _formKey.currentState!.validate();
    final now = ref.read(clockProvider)();
    if (!textValid || !_data.pickersValid(l10n, now)) return;

    final input = _data.toInput();
    final slotLimit = input.slotLimit;
    final dataChanged =
        input.locationName != _original.locationName ||
        input.mapsUrl != _original.mapsUrl ||
        input.cancellationDeadline != _original.cancellationDeadline ||
        input.startsAt != _original.startsAt ||
        input.endsAt != _original.endsAt ||
        input.totalCents != _original.totalCents;
    final limitChanged = slotLimit != _original.slotLimit;

    // Sem mudança, só volta (telas.md, 7.4).
    if (!dataChanged && !limitChanged) {
      context.pop();
      return;
    }
    final error = await ref
        .read(gameFormControllerProvider.notifier)
        .save(
          gameId: _original.id,
          newSlotLimit: limitChanged ? slotLimit : null,
          input: dataChanged ? input : null,
        );
    if (!mounted) return;
    if (error == null) {
      showSnack(context, l10n.gameSaved);
      context.pop();
      return;
    }
    showErrorSnack(context, error);
    // O jogo começou ou foi cancelado nesse meio tempo: volta ao detalhe.
    if (error.hasCode(ErrorCode.gameStarted) ||
        error.hasCode(ErrorCode.gameNotOpen)) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(gameFormControllerProvider).isLoading;
    final now = ref.watch(clockProvider)();
    final occupied = widget.game.occupiedSlots;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // O grupo não muda depois da criação: só texto (telas.md, 7.4).
            FieldLabel(l10n.gameGroupLabel),
            Row(
              children: [
                Icon(
                  _original.groupId == null ? Symbols.person : Symbols.groups,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _original.groupName ?? l10n.gameStandalone,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GameFormFields(
              data: _data,
              showErrors: _showErrors,
              now: now,
              enabled: !busy,
              // O limite não fica abaixo das vagas ocupadas (RN59).
              minSlots: occupied < 1 ? 1 : occupied,
              slotsHelper: l10n.gameSlotsOccupiedHint(occupied),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: l10n.commonSave,
              loading: busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
