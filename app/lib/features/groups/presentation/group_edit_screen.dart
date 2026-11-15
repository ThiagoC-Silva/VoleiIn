import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/photo_picker.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/group_models.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';
import 'group_name_field.dart';
import 'groups_providers.dart';

/// Editar grupo (RF18, RF103, RN17; docs/ui/telas.md, 6.8; groupEdit.png).
/// Só para admins: a tela confere o papel antes de mostrar o formulário.
/// Nome e foto são gravados juntos, no Salvar. Voltar descarta as alterações,
/// sem confirmação.
class GroupEditScreen extends ConsumerWidget {
  const GroupEditScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final group = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      appBar: InnerAppBar(title: l10n.groupEdit),
      body: switch (group) {
        AsyncValue(:final value?) when !value.isAdmin => ErrorStateView(
          error: const AppException(ErrorCode.notFound),
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        AsyncValue(:final value?) => _EditForm(group: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.group});

  final GroupDetail group;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.group.name,
  );
  PhotoChange _photo = const PhotoKept();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GroupFormController get _controller =>
      ref.read(groupFormControllerProvider.notifier);

  bool get _hasPhoto => switch (_photo) {
    PhotoReplaced() => true,
    PhotoRemoved() => false,
    PhotoKept() => widget.group.photoPath != null,
  };

  Future<void> _changePhoto() async {
    final action = await showPhotoSheet(context, canRemove: _hasPhoto);
    if (action == null || !mounted) return;
    if (action == PhotoAction.remove) {
      setState(() => _photo = const PhotoRemoved());
      return;
    }
    try {
      final picked = await _controller.pickPhoto(
        action == PhotoAction.camera ? PhotoSource.camera : PhotoSource.gallery,
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
    final error = await _controller.save(
      groupId: widget.group.id,
      name: _name.text.trim(),
      currentPhotoPath: widget.group.photoPath,
      photo: _photo,
    );
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSnack(context, l10n.groupSaved);
    context.pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.groupDeleteTitle(widget.group.name),
      body: l10n.groupDeleteBody,
      confirmLabel: l10n.groupDelete,
    );
    if (!confirmed || !mounted) return;
    final error = await _controller.archive(widget.group.id);
    if (!mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
      return;
    }
    showSnack(context, l10n.groupDeleted);
    context.goNamed(Routes.groups);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(groupFormControllerProvider).isLoading;
    final group = widget.group;
    final photo = _photo;

    return Form(
      key: _formKey,
      child: FormScrollView(
        content: [
          Center(
            child: GroupAvatarView(
              id: group.id,
              name: _name.text,
              photoPath: photo is PhotoKept ? group.photoPath : null,
              imageBytes: photo is PhotoReplaced ? photo.photo.bytes : null,
              size: 96,
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
          GroupNameField(
            controller: _name,
            enabled: !busy,
            onChanged: (_) => setState(() {}),
          ),
        ],
        footer: [
          PrimaryButton(
            label: l10n.commonSave,
            loading: busy,
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          DestructiveOutlinedButton(
            label: l10n.groupDelete,
            onPressed: busy ? null : _delete,
          ),
        ],
      ),
    );
  }
}
