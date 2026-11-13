import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/format/phone.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/field_label.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/inner_scaffold.dart';
import '../../../shared/widgets/loading_button.dart';
import '../../../shared/widgets/masked_input_formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/photo_picker.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'profile_providers.dart';
import 'profile_screen.dart' show ProfilePhotoAvatar;

final _saveProvider = AsyncNotifierProvider.autoDispose<ActionController, void>(
  ActionController.new,
);

/// Editar nome, apelido, foto, telefone e a visibilidade do telefone (RF08 a
/// RF10, RF12; docs/ui/telas.md, 5.8; profileEdit.png e profileEdit-foto.png).
/// Tudo é gravado junto, no Salvar. Voltar sem salvar descarta as alterações.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(ownProfileProvider);
    return switch (profile) {
      AsyncData(:final value) => _EditForm(data: value),
      AsyncError(:final error) => InnerScaffold(
        title: l10n.profileEdit,
        body: ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
      ),
      _ => InnerScaffold(title: l10n.profileEdit, body: const LoadingState()),
    };
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.data});

  final OwnProfile data;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _phone;
  late bool _phoneVisible;

  /// Foto escolhida e ainda não enviada.
  PickedPhoto? _newPhoto;

  /// A pessoa tocou em Remover foto (vale só no Salvar).
  bool _photoRemoved = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.data.profile;
    final private = widget.data.private;
    _name = TextEditingController(text: profile.name);
    _nickname = TextEditingController(text: profile.nickname);
    _phone = TextEditingController(
      text: private.phone == null
          ? ''
          : formatNationalPhone(nationalDigits(private.phone!)),
    );
    _phoneVisible = private.phoneVisible && private.phone != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasPhoto =>
      _newPhoto != null ||
      (!_photoRemoved && widget.data.profile.photoPath != null);

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _choosePhoto() async {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      useSafeArea: true,
      // Sem título (referencias/README, conferência dos PNGs).
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetOption(
                icon: Symbols.photo_library,
                label: l10n.profilePhotoGallery,
                onTap: () => Navigator.pop(context, _PhotoChoice.gallery),
              ),
              _SheetOption(
                icon: Symbols.photo_camera,
                label: l10n.profilePhotoCamera,
                onTap: () => Navigator.pop(context, _PhotoChoice.camera),
              ),
              if (_hasPhoto)
                _SheetOption(
                  icon: Symbols.delete,
                  label: l10n.profilePhotoRemove,
                  color: colors.error,
                  onTap: () => Navigator.pop(context, _PhotoChoice.remove),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == _PhotoChoice.remove) {
      // Sem confirmação: só vale ao tocar em Salvar (telas.md, 5.8).
      setState(() {
        _newPhoto = null;
        _photoRemoved = true;
      });
      return;
    }
    try {
      final picked = await ref
          .read(photoPickerProvider)
          .pick(
            choice == _PhotoChoice.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
          );
      if (picked != null && mounted) setState(() => _newPhoto = picked);
    } catch (error) {
      if (mounted) _snack(errorTextFor(l10n, error));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(profileRepositoryProvider);
    final oldPath = widget.data.profile.photoPath;
    final nickname = _nickname.text.trim();
    final phone = _phone.text.trim().isEmpty ? null : phoneToE164(_phone.text);
    final photo = _newPhoto;
    final removed = _photoRemoved;

    final ok = await ref.read(_saveProvider.notifier).run(() async {
      // Ordem do telas.md, 5.8: foto nova, profiles, profile_private e, por
      // último, a remoção da foto antiga.
      final newPath = photo == null
          ? null
          : await repository.uploadPhoto(photo.bytes, photo.type);
      await repository.updateProfile(
        name: _name.text.trim(),
        // Apelido apagado vira nulo, e o nome exibido volta ao nome (RN100).
        nickname: nickname.isEmpty ? null : nickname,
        photoPath: newPath ?? (removed ? null : oldPath),
      );
      await repository.updatePrivate(
        phone: phone,
        phoneVisible: phone != null && _phoneVisible,
      );
      if (oldPath != null && (newPath != null || removed)) {
        try {
          await repository.deletePhoto(oldPath);
        } catch (_) {
          // O perfil já está salvo; o arquivo fica para a limpeza da fatia 6.
        }
      }
    });
    if (!mounted) return;
    if (!ok) return _snack(errorTextFor(l10n, ref.read(_saveProvider).error!));

    ref.invalidate(ownProfileProvider);
    _snack(l10n.profileSaved);
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saving = ref.watch(_saveProvider).isLoading;
    final hasPhone = _phone.text.trim().isNotEmpty;

    return InnerScaffold(
      title: l10n.profileEdit,
      footer: PrimaryButton(
        label: l10n.commonSave,
        loading: saving,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProfilePhotoAvatar(
                profile: widget.data.profile,
                size: 96,
                pickedImage: _newPhoto == null
                    ? null
                    : MemoryImage(_newPhoto!.bytes),
                hidePhoto: _photoRemoved,
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: saving ? null : _choosePhoto,
                icon: const Icon(Symbols.photo_camera),
                label: Text(l10n.profileChangePhoto),
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.authNameLabel),
            TextFormField(
              controller: _name,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final name = (value ?? '').trim();
                if (name.isEmpty) return l10n.authNameRequired;
                if (name.length > 80) return l10n.authNameTooLong;
                return null;
              },
            ),
            const SizedBox(height: 16),
            FieldLabel(l10n.profileNicknameLabel),
            TextFormField(
              controller: _nickname,
              enabled: !saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (value) => (value ?? '').trim().length > 30
                  ? l10n.profileNicknameTooLong
                  : null,
            ),
            FieldHint(l10n.profileNicknameHint),
            const SizedBox(height: 16),
            FieldLabel(l10n.profilePhoneLabel),
            TextFormField(
              controller: _phone,
              enabled: !saving,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [phoneInputFormatter()],
              decoration: InputDecoration(
                prefixText: '+55  ',
                prefixStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onChanged: (value) => setState(() {
                // Apagar o telefone desliga o interruptor (telas.md, 5.8).
                if (value.trim().isEmpty) _phoneVisible = false;
              }),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                return phoneToE164(text) == null
                    ? l10n.profilePhoneInvalid
                    : null;
              },
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
                        FieldHint(l10n.profilePhoneVisibleHint),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Oculto por padrão e desabilitado sem telefone (RN101).
                  Switch(
                    value: _phoneVisible,
                    onChanged: saving || !hasPhone
                        ? null
                        : (value) => setState(() => _phoneVisible = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoChoice { gallery, camera, remove }

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
    return ListTile(
      minTileHeight: 64,
      leading: IconSquare(icon: icon, foreground: color),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
