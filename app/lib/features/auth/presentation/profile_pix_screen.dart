import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/format/phone.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/masked_input_formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/profile_repository.dart';
import '../domain/pix_key_type.dart';
import '../domain/profile.dart';
import 'pix_key_labels.dart';
import 'profile_providers.dart';

final _saveProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);
final _removeProvider =
    AsyncNotifierProvider.autoDispose<ActionController, void>(
      ActionController.new,
    );

/// Cadastrar, trocar e remover a chave Pix (RF11, RF12, RN105;
/// docs/ui/telas.md, 5.9; profilePix.png, profilePix-tipo.png e
/// profilePix-remover.png).
class ProfilePixScreen extends ConsumerWidget {
  const ProfilePixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(ownProfileProvider);
    return switch (profile) {
      AsyncData(:final value) => _PixForm(data: value),
      AsyncError(:final error) => InnerScaffold(
        title: l10n.profilePix,
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
      ),
      _ => InnerScaffold(title: l10n.profilePix, body: const LoadingState()),
    };
  }
}

class _PixForm extends ConsumerStatefulWidget {
  const _PixForm({required this.data});

  final OwnProfile data;

  @override
  ConsumerState<_PixForm> createState() => _PixFormState();
}

class _PixFormState extends ConsumerState<_PixForm> {
  final _formKey = GlobalKey<FormState>();
  final _key = TextEditingController();
  late PixKeyType _type;

  @override
  void initState() {
    super.initState();
    final private = widget.data.private;
    _type = private.pixKeyType ?? PixKeyType.cpf;
    final stored = private.pixKey;
    if (stored != null) _key.text = _editableText(_type, stored);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  bool get _hasKey => widget.data.private.pixKey != null;

  /// Chave gravada como aparece no campo, com a máscara do tipo. O telefone
  /// mostra só DDD e número, porque o `+55` é fixo no campo.
  static String _editableText(PixKeyType type, String stored) =>
      type == PixKeyType.phone
      ? formatNationalPhone(nationalDigits(stored))
      : type.format(stored);

  void _selectType(PixKeyType type) {
    if (type == _type) return;
    // Trocar o tipo limpa o campo (telas.md, 5.9).
    setState(() {
      _type = type;
      _key.clear();
    });
    _formKey.currentState?.reset();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _done() {
    ref.invalidate(ownProfileProvider);
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.profile);
    }
  }

  Future<void> _save() async {
    // Chave inválida para o tipo: erro no campo, sem chamar o servidor.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final type = _type;
    final key = type.normalize(_key.text);
    final ok = await ref
        .read(_saveProvider.notifier)
        .run(() => ref.read(profileRepositoryProvider).savePixKey(type, key));
    if (!mounted) return;
    if (!ok) return _snack(errorTextFor(l10n, ref.read(_saveProvider).error!));
    _snack(l10n.pixSaved);
    _done();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDestructiveConfirm(
      context,
      title: l10n.pixRemoveTitle,
      body: l10n.pixRemoveBody,
      confirmLabel: l10n.pixRemoveConfirm,
      cancelLabel: l10n.commonBack,
    );
    if (!confirmed || !mounted) return;
    final ok = await ref
        .read(_removeProvider.notifier)
        .run(() => ref.read(profileRepositoryProvider).removePixKey());
    if (!mounted) return;
    // Remoção recusada (PIX_KEY_IN_USE, RN105): aviso, e a chave continua.
    if (!ok) {
      return _snack(errorTextFor(l10n, ref.read(_removeProvider).error!));
    }
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saving = ref.watch(_saveProvider).isLoading;
    final removing = ref.watch(_removeProvider).isLoading;
    final busy = saving || removing;

    return InnerScaffold(
      title: l10n.profilePix,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: l10n.commonSave,
            loading: saving,
            onPressed: busy ? null : _save,
          ),
          if (_hasKey) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: busy ? null : _remove,
              child: removing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(l10n.pixRemove),
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(l10n.pixTypeLabel),
            _PixTypeMenu(
              selected: _type,
              enabled: !busy,
              onSelected: _selectType,
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.pixKeyLabel),
            TextFormField(
              key: ValueKey(_type),
              controller: _key,
              enabled: !busy,
              keyboardType: switch (_type) {
                PixKeyType.cpf || PixKeyType.cnpj => TextInputType.number,
                PixKeyType.email => TextInputType.emailAddress,
                PixKeyType.phone => TextInputType.phone,
                PixKeyType.random => TextInputType.text,
              },
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: switch (_type) {
                PixKeyType.cpf => [cpfInputFormatter()],
                PixKeyType.cnpj => [cnpjInputFormatter()],
                PixKeyType.phone => [phoneInputFormatter()],
                PixKeyType.email || PixKeyType.random => <TextInputFormatter>[],
              },
              decoration: InputDecoration(
                prefixText: _type == PixKeyType.phone ? '+55  ' : null,
                prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              validator: (value) =>
                  _type.isValid(value ?? '') ? null : _type.invalidText(l10n),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu suspenso do tipo da chave, com um ícone por opção e a marca na
/// escolhida (profilePix-tipo.png).
class _PixTypeMenu extends StatelessWidget {
  const _PixTypeMenu({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final PixKeyType selected;
  final bool enabled;
  final ValueChanged<PixKeyType> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(
            Size(constraints.maxWidth, double.infinity),
          ),
        ),
        menuChildren: [
          for (final type in PixKeyType.values)
            MenuItemButton(
              style: MenuItemButton.styleFrom(
                minimumSize: Size(constraints.maxWidth, 56),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: type == selected
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)
                    : null,
              ),
              leadingIcon: Icon(
                type.icon,
                color: type == selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              trailingIcon: type == selected
                  ? Icon(Symbols.check, color: theme.colorScheme.primary)
                  : null,
              onPressed: () => onSelected(type),
              child: Text(
                type.label(l10n),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: type == selected ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
        builder: (context, controller, _) => Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outline, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: !enabled
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconSquare(icon: selected.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selected.label(l10n),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Icon(
                      Symbols.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
