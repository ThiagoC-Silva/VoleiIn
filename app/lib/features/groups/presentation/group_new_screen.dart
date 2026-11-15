import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/photo_picker.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';
import 'group_name_field.dart';

/// Criar grupo (RF14; docs/ui/telas.md, 6.2; groupsNew.png). Voltar descarta
/// o que foi digitado, sem confirmação.
class GroupNewScreen extends ConsumerStatefulWidget {
  const GroupNewScreen({super.key});

  @override
  ConsumerState<GroupNewScreen> createState() => _GroupNewScreenState();
}

class _GroupNewScreenState extends ConsumerState<GroupNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  PickedPhoto? _photo;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final action = await showPhotoSheet(context, canRemove: _photo != null);
    if (action == null || !mounted) return;
    if (action == PhotoAction.remove) {
      setState(() => _photo = null);
      return;
    }
    try {
      final picked = await ref
          .read(groupFormControllerProvider.notifier)
          .pickPhoto(
            action == PhotoAction.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
          );
      if (picked != null && mounted) setState(() => _photo = picked);
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    }
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(groupFormControllerProvider.notifier)
        .create(name: _name.text.trim(), photo: _photo);
    if (!mounted) return;
    final groupId = result.groupId;
    if (result.error != null || groupId == null) {
      showErrorSnack(context, result.error!);
      return;
    }
    showSnack(
      context,
      result.photoFailed ? l10n.groupCreatedPhotoFailed : l10n.groupCreated,
    );
    // Troca a criação pelo detalhe: o voltar não retorna à criação.
    context.goNamed(Routes.group, pathParameters: {'groupId': groupId});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(groupFormControllerProvider).isLoading;

    return Scaffold(
      appBar: InnerAppBar(title: l10n.groupsCreate),
      body: Form(
        key: _formKey,
        child: FormScrollView(
          content: [
            Center(
              child: GroupAvatarView(
                id: 'new-group',
                name: _name.text,
                imageBytes: _photo?.bytes,
                size: 96,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: busy ? null : _choosePhoto,
                icon: const Icon(Symbols.photo_camera, size: 22),
                label: Text(l10n.groupChoosePhoto),
              ),
            ),
            const SizedBox(height: 16),
            GroupNameField(
              controller: _name,
              enabled: !busy,
              // As iniciais do avatar acompanham o nome digitado.
              onChanged: (_) => setState(() {}),
            ),
          ],
          footer: [
            PrimaryButton(
              label: l10n.groupsCreate,
              loading: busy,
              onPressed: _create,
            ),
          ],
        ),
      ),
    );
  }
}
