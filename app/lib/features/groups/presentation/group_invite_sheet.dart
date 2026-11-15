import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/share.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/group_models.dart';
import 'group_controllers.dart';
import 'groups_providers.dart';

/// Abre a sheet do convite sobre o detalhe (docs/ui/telas.md, 6.5).
Future<void> showGroupInviteSheet(BuildContext context, String groupId) =>
    showVoleiSheet<void>(context, (context) => GroupInviteSheet(groupId));

/// Convite do grupo (RF15, RN11; group-convite*.png). Usa o grupo já lido
/// pelo detalhe e o relê depois de cada ação. Todo membro vê, copia e
/// compartilha o código; só o admin gera um novo ou desativa.
class GroupInviteSheet extends ConsumerWidget {
  const GroupInviteSheet(this.groupId, {super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final busy = ref.watch(groupActionsControllerProvider).isLoading;
    return switch (group) {
      AsyncValue(:final value?) => _InviteContent(group: value, busy: busy),
      AsyncError(:final error) => ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
      ),
      _ => const Padding(padding: EdgeInsets.all(32), child: LoadingState()),
    };
  }
}

class _InviteContent extends ConsumerWidget {
  const _InviteContent({required this.group, required this.busy});

  final GroupDetail group;
  final bool busy;

  GroupActionsController _actions(WidgetRef ref) =>
      ref.read(groupActionsControllerProvider.notifier);

  Future<void> _copy(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) showSnack(context, l10n.groupInviteCopied);
  }

  Future<void> _share(BuildContext context, WidgetRef ref, String code) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(sharerProvider)
          .shareText(l10n.groupInviteShareText(group.name, code));
    } catch (_) {
      if (context.mounted) {
        showErrorSnack(context, const AppException(ErrorCode.internalError));
      }
    }
  }

  Future<void> _regenerate(
    BuildContext context,
    WidgetRef ref, {
    required bool confirm,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (confirm) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.groupInviteRegenerateTitle,
        body: l10n.groupInviteRegenerateBody,
        confirmLabel: l10n.groupInviteRegenerate,
      );
      if (!confirmed || !context.mounted) return;
    }
    final error = await _actions(ref).regenerateInvite(group.id);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
    } else if (confirm) {
      showSnack(context, l10n.groupInviteRegenerated);
    }
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.groupInviteDisableTitle,
      body: l10n.groupInviteDisableBody,
      confirmLabel: l10n.groupInviteDisableConfirm,
    );
    if (!confirmed || !context.mounted) return;
    final error = await _actions(ref).invalidateInvite(group.id);
    if (!context.mounted) return;
    if (error != null) {
      showErrorSnack(context, error);
    } else {
      showSnack(context, l10n.groupInviteDisabled);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = group.inviteCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.groupInviteTitle, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (code != null) ...[
          Text(l10n.groupInviteIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          _CodeBox(code: code),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : () => _share(context, ref, code),
            icon: const Icon(Symbols.share),
            label: Text(l10n.groupInviteShare),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _copy(context, code),
            icon: const Icon(Symbols.content_copy),
            label: Text(l10n.groupInviteCopy),
          ),
          if (group.isAdmin) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _regenerate(context, ref, confirm: true),
                  child: Text(l10n.groupInviteRegenerate),
                ),
                TextButton(
                  onPressed: busy ? null : () => _disable(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l10n.groupInviteDisable),
                ),
              ],
            ),
          ],
        ] else ...[
          Text(l10n.groupInviteOff, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          // Sem código a invalidar, o admin gera sem confirmação.
          if (group.isAdmin)
            PrimaryButton(
              label: l10n.groupInviteGenerate,
              loading: busy,
              onPressed: () => _regenerate(context, ref, confirm: false),
            )
          else
            Text(
              l10n.groupInviteAskAdmin,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

/// O código em destaque, selecionável. Roboto 700 22 com +2 entre as letras,
/// nunca Bebas Neue, que só tem maiúsculas e apagaria a diferença entre elas
/// (telas.md, 6.5; design-system.md, seção 5).
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: SelectionArea(
        child: Text(
          code,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
