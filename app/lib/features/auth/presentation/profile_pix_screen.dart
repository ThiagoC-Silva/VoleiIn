import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/input_masks.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/pix_key.dart';
import '../domain/profile_private.dart';
import 'pix_key_label.dart';
import 'profile_pix_controller.dart';
import 'profile_providers.dart';

/// Chave Pix (docs/ui/telas.md, 5.9; profilePix.png, profilePix-tipo.png e
/// profilePix-remover.png).
class ProfilePixScreen extends ConsumerWidget {
  const ProfilePixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(ownProfileProvider);
    return Scaffold(
      appBar: InnerAppBar(title: l10n.profilePix),
      body: switch (profile) {
        AsyncValue(:final value?) => _PixForm(private: value.private),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _PixForm extends ConsumerStatefulWidget {
  const _PixForm({required this.private});

  final ProfilePrivate private;

  @override
  ConsumerState<_PixForm> createState() => _PixFormState();
}

class _PixFormState extends ConsumerState<_PixForm> {
  final _formKey = GlobalKey<FormState>();
  late PixKeyType _type;
  late final TextEditingController _key;

  bool get _hasSavedKey => widget.private.pixKey != null;

  @override
  void initState() {
    super.initState();
    final type = widget.private.pixKeyType;
    final key = widget.private.pixKey;
    _type = type ?? PixKeyType.cpf;
    _key = TextEditingController(
      text: type == null || key == null ? '' : pixKeyForField(type, key),
    );
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  /// Trocar o tipo limpa o campo.
  void _changeType(PixKeyType type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _key.clear();
    });
  }

  String? _validate(AppLocalizations l10n, String? value) {
    if (isValidPixKey(_type, value ?? '')) return null;
    return switch (_type) {
      PixKeyType.cpf => l10n.pixInvalidCpf,
      PixKeyType.cnpj => l10n.pixInvalidCnpj,
      PixKeyType.email => l10n.pixInvalidEmail,
      PixKeyType.phone => l10n.pixInvalidPhone,
      PixKeyType.random => l10n.pixInvalidRandom,
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final error = await ref
        .read(profilePixControllerProvider.notifier)
        .save(_type, _key.text);
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSnack(context, l10n.pixSaved);
    context.pop();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.pixRemoveTitle,
      body: l10n.pixRemoveBody,
      confirmLabel: l10n.pixRemoveConfirm,
    );
    if (!confirmed || !mounted) return;
    final error = await ref
        .read(profilePixControllerProvider.notifier)
        .remove();
    if (!mounted) return;
    if (error != null) {
      // PIX_KEY_IN_USE: a chave continua (RN105).
      showErrorSnack(context, error);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(profilePixControllerProvider).isLoading;
    final (keyboard, formatters) = switch (_type) {
      PixKeyType.cpf => (TextInputType.number, [DigitMaskFormatter.cpf]),
      PixKeyType.cnpj => (TextInputType.number, [DigitMaskFormatter.cnpj]),
      PixKeyType.phone => (TextInputType.phone, [DigitMaskFormatter.phone]),
      PixKeyType.email => (TextInputType.emailAddress, <TextInputFormatter>[]),
      PixKeyType.random => (TextInputType.text, <TextInputFormatter>[]),
    };

    return Form(
      key: _formKey,
      child: FormScrollView(
        content: [
          FieldLabel(l10n.pixTypeLabel),
          _PixTypeSelector(
            key: const Key('pixTypeSelector'),
            value: _type,
            enabled: !busy,
            onChanged: _changeType,
          ),
          const SizedBox(height: 16),
          LabeledField(
            // Um campo novo por tipo, com o teclado e a máscara do tipo.
            key: ValueKey(_type),
            label: l10n.pixKeyLabel,
            controller: _key,
            enabled: !busy,
            keyboardType: keyboard,
            inputFormatters: formatters,
            autocorrect: false,
            prefixText: _type == PixKeyType.phone ? '+55  ' : null,
            validator: (value) => _validate(l10n, value),
          ),
        ],
        footer: [
          PrimaryButton(
            label: l10n.commonSave,
            loading: busy,
            onPressed: _save,
          ),
          if (_hasSavedKey) ...[
            const SizedBox(height: 12),
            DestructiveOutlinedButton(
              label: l10n.pixRemove,
              onPressed: busy ? null : _remove,
            ),
          ],
        ],
      ),
    );
  }
}

/// Menu suspenso do tipo, com um ícone por opção e a marca na escolhida
/// (profilePix-tipo.png).
class _PixTypeSelector extends StatelessWidget {
  const _PixTypeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final PixKeyType value;
  final bool enabled;
  final ValueChanged<PixKeyType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            theme.colorScheme.surfaceContainerHigh,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        alignmentOffset: const Offset(0, 8),
        menuChildren: [
          for (final type in PixKeyType.values)
            SizedBox(
              width: constraints.maxWidth,
              child: MenuItemButton(
                onPressed: () => onChanged(type),
                style: MenuItemButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: type == value
                      ? theme.colorScheme.onSurface.withValues(alpha: .12)
                      : null,
                ),
                leadingIcon: Icon(
                  pixKeyTypeIcon(type),
                  color: type == value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                trailingIcon: type == value
                    ? Icon(Symbols.check, color: theme.colorScheme.primary)
                    : null,
                child: Text(
                  pixKeyTypeLabel(l10n, type),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: type == value
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
        builder: (context, menu, _) => Semantics(
          button: true,
          label: l10n.pixTypeLabel,
          value: pixKeyTypeLabel(l10n, value),
          excludeSemantics: true,
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: menu.isOpen
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHigh,
                width: menu.isOpen ? 2 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: !enabled
                  ? null
                  : () => menu.isOpen ? menu.close() : menu.open(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconSquare(icon: pixKeyTypeIcon(value)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pixKeyTypeLabel(l10n, value),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        menu.isOpen
                            ? Symbols.keyboard_arrow_up
                            : Symbols.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
