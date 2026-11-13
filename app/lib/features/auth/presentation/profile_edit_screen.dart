import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/input_masks.dart';
import '../../../core/format/phone.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/photo_picker.dart';
import '../domain/own_profile.dart';
import 'access_validators.dart';
import 'profile_edit_controller.dart';
import 'profile_providers.dart';

/// Editar perfil (docs/ui/telas.md, 5.8; profileEdit.png e
/// profileEdit-foto.png). Tudo é gravado junto, no Salvar. Voltar descarta as
/// alterações, sem confirmação.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(ownProfileProvider);
    return Scaffold(
      appBar: InnerAppBar(title: l10n.profileEdit),
      body: switch (profile) {
        AsyncValue(:final value?) => _EditForm(own: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.own});

  final OwnProfile own;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

enum _PhotoAction { gallery, camera, remove }

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _phone;
  late bool _phoneVisible;
  PhotoChange _photo = const PhotoKept();

  @override
  void initState() {
    super.initState();
    final profile = widget.own.profile;
    final private = widget.own.private;
    _name = TextEditingController(text: profile.name);
    _nickname = TextEditingController(text: profile.nickname);
    _phone = TextEditingController(
      text: private.phone == null ? '' : formatPhone(private.phone!),
    );
    _phoneVisible = private.phone != null && private.phoneVisible;
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasPhone => _phone.text.trim().isNotEmpty;

  bool get _hasPhoto => switch (_photo) {
    PhotoReplaced() => true,
    PhotoRemoved() => false,
    PhotoKept() => widget.own.profile.photoPath != null,
  };

  Future<void> _changePhoto() async {
    final l10n = AppLocalizations.of(context);
    final action = await showVoleiSheet<_PhotoAction>(
      context,
      (context) => _PhotoSheet(l10n: l10n, canRemove: _hasPhoto),
    );
    if (action == null || !mounted) return;
    if (action == _PhotoAction.remove) {
      setState(() => _photo = const PhotoRemoved());
      return;
    }
    try {
      final picked = await ref
          .read(profileEditControllerProvider.notifier)
          .pickPhoto(
            action == _PhotoAction.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
          );
      if (picked != null && mounted) {
        setState(() => _photo = PhotoReplaced(picked));
      }
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final nickname = _nickname.text.trim();
    final phone = _hasPhone ? phoneToE164(_phone.text) : null;
    final error = await ref
        .read(profileEditControllerProvider.notifier)
        .save(
          name: _name.text.trim(),
          nickname: nickname.isEmpty ? null : nickname,
          phone: phone,
          phoneVisible: phone != null && _phoneVisible,
          currentPhotoPath: widget.own.profile.photoPath,
          photo: _photo,
        );
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSnack(context, l10n.profileSaved);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final validators = AccessValidators(l10n);
    final busy = ref.watch(profileEditControllerProvider).isLoading;
    final profile = widget.own.profile;
    final photoPath = profile.photoPath;
    final photoUrl = _photo is PhotoKept && photoPath != null
        ? ref.watch(avatarUrlProvider(photoPath)).value
        : null;
    final photo = _photo;

    return Form(
      key: _formKey,
      child: FormScrollView(
        content: [
          Center(
            child: VoleiAvatar(
              id: profile.id,
              isYou: true,
              name: profile.displayName,
              size: 96,
              imageUrl: photoUrl,
              imageBytes: photo is PhotoReplaced ? photo.photo.bytes : null,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : _changePhoto,
              icon: const Icon(Symbols.photo_camera, size: 22),
              label: Text(l10n.profileChangePhoto),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: l10n.authNameLabel,
            controller: _name,
            enabled: !busy,
            autofillHints: const [AutofillHints.name],
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: validators.name,
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: l10n.profileNicknameLabel,
            controller: _nickname,
            enabled: !busy,
            helperText: l10n.profileNicknameHint,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                (value ?? '').trim().length > AccessValidators.nicknameMax
                ? l10n.profileNicknameTooLong
                : null,
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: l10n.profilePhoneLabel,
            controller: _phone,
            enabled: !busy,
            prefixText: '+55  ',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [DigitMaskFormatter.phone],
            // Apagar o telefone desliga o interruptor.
            onChanged: (_) => setState(() {
              if (!_hasPhone) _phoneVisible = false;
            }),
            validator: (value) =>
                (value ?? '').trim().isNotEmpty && phoneToE164(value!) == null
                ? l10n.profilePhoneInvalid
                : null,
          ),
          const SizedBox(height: 16),
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.profilePhoneVisible,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        l10n.profilePhoneVisibleHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _hasPhone && _phoneVisible,
                  onChanged: busy || !_hasPhone
                      ? null
                      : (value) => setState(() => _phoneVisible = value),
                ),
              ],
            ),
          ),
        ],
        footer: [
          PrimaryButton(
            label: l10n.commonSave,
            loading: busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Sheet da foto, sem título (docs/ui/telas.md, 5.8; decisão de 12/11/2026).
/// Remover foto fica em tom destrutivo e sem confirmação: só vale no Salvar.
class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.l10n, required this.canRemove});

  final AppLocalizations l10n;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetOption(
          icon: Symbols.photo_library,
          label: l10n.profilePhotoGallery,
          onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
        ),
        const Divider(height: 1, indent: 56),
        _SheetOption(
          icon: Symbols.photo_camera,
          label: l10n.profilePhotoCamera,
          onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
        ),
        if (canRemove) ...[
          const Divider(height: 1, indent: 56),
          _SheetOption(
            icon: Symbols.delete,
            label: l10n.profilePhotoRemove,
            color: error,
            onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
          ),
        ],
      ],
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Row(
          children: [
            IconSquare(icon: icon, foreground: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
