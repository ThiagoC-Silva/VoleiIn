import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/clock.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/format/names.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/picker_field.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../domain/game_models.dart';
import 'game_controllers.dart';
import 'game_form.dart';
import 'games_providers.dart';

/// O grupo escolhido na criação: um grupo, o avulso ou nenhum ainda.
sealed class _GroupChoice {
  const _GroupChoice();
}

class _NoGroup extends _GroupChoice {
  const _NoGroup();
}

class _Standalone extends _GroupChoice {
  const _Standalone();
}

class _InGroup extends _GroupChoice {
  const _InGroup(this.option);
  final GameGroupOption option;
}

/// Criar jogo (RF26 a RF32; docs/ui/telas.md, 7.2; gamesNew.png e
/// gamesNew-semPix.png). Cobre a barra inferior. Abre de Meus jogos, sem
/// grupo, ou do detalhe do grupo, com o [groupId]. Quem cria vira o admin, o
/// recebedor e o primeiro da lista (RN21).
class GameNewScreen extends ConsumerStatefulWidget {
  const GameNewScreen({this.groupId, super.key});

  final String? groupId;

  @override
  ConsumerState<GameNewScreen> createState() => _GameNewScreenState();
}

class _GameNewScreenState extends ConsumerState<GameNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = GameFormData();
  _GroupChoice? _choice;
  bool _showErrors = false;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  /// O grupo vem escolhido pelo detalhe do grupo ou quando a pessoa tem um
  /// grupo só (telas.md, 7.2). Depois que ela escolhe, a escolha fica.
  _GroupChoice _initialChoice(List<GameGroupOption> options) {
    for (final option in options) {
      if (option.id == widget.groupId) return _InGroup(option);
    }
    if (widget.groupId == null && options.length == 1) {
      return _InGroup(options.single);
    }
    return const _NoGroup();
  }

  Future<void> _chooseGroup(List<GameGroupOption> options) async {
    final l10n = AppLocalizations.of(context);
    final sorted = [...options]..sort((a, b) => compareNames(a.name, b.name));
    final choice = await showVoleiSheet<_GroupChoice>(context, (context) {
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.gameGroupSheetTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          SheetOptions(
            options: [
              for (final option in sorted)
                SheetOption(
                  icon: Symbols.groups,
                  label: option.name,
                  onTap: () => Navigator.of(context).pop(_InGroup(option)),
                ),
              SheetOption(
                icon: Symbols.person,
                label: l10n.gameStandalone,
                onTap: () => Navigator.of(context).pop(const _Standalone()),
              ),
            ],
          ),
        ],
      );
    });
    if (choice != null && mounted) setState(() => _choice = choice);
  }

  Future<void> _openPix() async {
    await context.pushNamed(Routes.profilePix);
    // Ao voltar, relê a chave e mantém o que foi digitado (telas.md, 7.2).
    if (mounted) ref.invalidate(ownHasPixKeyProvider);
  }

  Future<void> _create(_GroupChoice choice) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _showErrors = true);
    final textValid = _formKey.currentState!.validate();
    final now = ref.read(clockProvider)();
    if (!textValid || !_data.pickersValid(l10n, now) || choice is _NoGroup) {
      return;
    }
    final groupId = choice is _InGroup ? choice.option.id : null;
    final (gameId, error) = await ref
        .read(gameFormControllerProvider.notifier)
        .create(groupId: groupId, input: _data.toInput());
    if (!mounted) return;
    if (error != null) {
      // A chave removida em outro aparelho: a tela relê e mostra o aviso.
      if (!error.hasCode(ErrorCode.receiverNeedsPixKey)) {
        showErrorSnack(context, error);
      }
      return;
    }
    showSnack(context, l10n.gameCreated);
    // Troca a criação pelo detalhe, que não volta para cá.
    context.goNamed(Routes.game, pathParameters: {'gameId': gameId!});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = VoleiColors.of(context);
    final busy = ref.watch(gameFormControllerProvider).isLoading;
    final hasPix = ref.watch(ownHasPixKeyProvider).value;
    final options = ref.watch(gameGroupOptionsProvider).value;
    final now = ref.watch(clockProvider)();
    final choice =
        _choice ??
        (options == null ? const _NoGroup() : _initialChoice(options));

    return Scaffold(
      appBar: InnerAppBar(title: l10n.gamesCreate),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasPix == false) ...[
                InlineNotice(
                  icon: Symbols.qr_code_2,
                  color: colors.owe,
                  text: l10n.gamePixNeededBody,
                  action: OutlinedButton(
                    onPressed: _openPix,
                    child: Text(
                      l10n.gamePixNeededAction,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              PickerField(
                key: const Key('gameGroupField'),
                label: l10n.gameGroupLabel,
                semanticLabel: l10n.gameGroupLabel,
                value: switch (choice) {
                  _InGroup(:final option) => option.name,
                  _Standalone() => l10n.gameStandalone,
                  _NoGroup() => l10n.gameGroupPlaceholder,
                },
                leading: IconSquare(
                  icon: choice is _Standalone ? Symbols.person : Symbols.groups,
                  size: 40,
                ),
                icon: Symbols.expand_more,
                enabled: !busy && options != null,
                errorText: _showErrors && choice is _NoGroup
                    ? l10n.gameGroupRequired
                    : null,
                helperText: choice is _Standalone
                    ? l10n.gameGroupStandaloneHint
                    : null,
                onTap: () => _chooseGroup(options ?? const []),
              ),
              const SizedBox(height: 20),
              GameFormFields(
                data: _data,
                showErrors: _showErrors,
                now: now,
                enabled: !busy,
                onChanged: () => setState(() {}),
              ),
              if (hasPix == true) ...[
                const SizedBox(height: 20),
                InlineNotice(
                  icon: Symbols.qr_code_2,
                  color: colors.receive,
                  text: l10n.gameReceiverNotice,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: l10n.gamesCreate,
                loading: busy,
                // Sem chave Pix, não há recebedor (RN22).
                onPressed: hasPix == true ? () => _create(choice) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
