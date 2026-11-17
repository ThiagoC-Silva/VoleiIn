import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/date_time.dart';
import '../../../core/router/routes.dart';
import '../../../core/format/names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/badge.dart';
import '../../../shared/widgets/confirm_sheet.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/list_card.dart';
import '../../../shared/widgets/sheet_option.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/group_models.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';
import 'group_screen.dart';
import 'groups_providers.dart';

/// Opções da sheet do admin (docs/ui/telas.md, 6.6).
enum _MemberAction { viewProfile, makeAdmin, makeMember, remove, stepDown }

/// Integrantes (RF19, RF20, RF23, RF24; telas.md, 6.6; groupMembers.png e
/// groupMembers-acoes.png). Primeiro os admins, depois os demais, cada bloco
/// em ordem alfabética.
class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({required this.groupId, this.blocked, super.key});

  final String groupId;

  /// A sheet de bloqueio da remoção (telas.md, 7.7 e 7.8), do roteador.
  final GroupBlockedSheet? blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(groupMembersProvider(groupId));
    // Mantém o controller vivo enquanto a tela estiver aberta.
    ref.watch(groupActionsControllerProvider);
    return Scaffold(
      appBar: InnerAppBar(title: l10n.groupMembers),
      body: switch (members) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(groupMembersProvider(groupId).future),
          child: _MemberList(
            groupId: groupId,
            members: value,
            blocked: blocked,
          ),
        ),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.groupId,
    required this.members,
    this.blocked,
  });

  final String groupId;
  final GroupBlockedSheet? blocked;
  final List<GroupMember> members;

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref, {
    required GroupMember member,
    required bool isMe,
    required bool iAmAdmin,
  }) async {
    if (!iAmAdmin) {
      await context.pushNamed(
        Routes.person,
        pathParameters: {'userId': member.userId},
      );
      return;
    }
    final action = await _showActions(context, member, isMe: isMe);
    if (action == null || !context.mounted) return;
    await _run(context, ref, action, member);
  }

  Future<_MemberAction?> _showActions(
    BuildContext context,
    GroupMember member, {
    required bool isMe,
  }) {
    final l10n = AppLocalizations.of(context);
    return showVoleiSheet<_MemberAction>(context, (context) {
      final theme = Theme.of(context);
      final error = theme.colorScheme.error;
      void pick(_MemberAction action) => Navigator.of(context).pop(action);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isMe ? l10n.groupMemberYou(member.displayName) : member.displayName,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          SheetOptions(
            options: isMe
                ? [
                    SheetOption(
                      icon: Symbols.remove_moderator,
                      label: l10n.groupStepDown,
                      color: error,
                      onTap: () => pick(_MemberAction.stepDown),
                    ),
                  ]
                : [
                    SheetOption(
                      icon: Symbols.person,
                      label: l10n.groupMemberViewProfile,
                      onTap: () => pick(_MemberAction.viewProfile),
                    ),
                    if (member.role == GroupRole.admin)
                      SheetOption(
                        icon: Symbols.remove_moderator,
                        label: l10n.groupMemberMakeMember,
                        onTap: () => pick(_MemberAction.makeMember),
                      )
                    else
                      SheetOption(
                        icon: Symbols.shield_person,
                        label: l10n.groupMemberMakeAdmin,
                        onTap: () => pick(_MemberAction.makeAdmin),
                      ),
                    SheetOption(
                      icon: Symbols.person_remove,
                      label: l10n.groupMemberRemove,
                      color: error,
                      onTap: () => pick(_MemberAction.remove),
                    ),
                  ],
          ),
        ],
      );
    });
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    _MemberAction action,
    GroupMember member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(groupActionsControllerProvider.notifier);
    final name = member.displayName;

    Future<void> setRole(GroupRole role, String done) async {
      final error = await actions.setRole(
        groupId: groupId,
        userId: member.userId,
        role: role,
      );
      if (!context.mounted) return;
      error == null ? showSnack(context, done) : showErrorSnack(context, error);
    }

    switch (action) {
      case _MemberAction.viewProfile:
        await context.pushNamed(
          Routes.person,
          pathParameters: {'userId': member.userId},
        );
      // Sem confirmação (telas.md, 6.6).
      case _MemberAction.makeAdmin:
        await setRole(GroupRole.admin, l10n.groupMemberNowAdmin(name));
      case _MemberAction.makeMember:
        await setRole(GroupRole.member, l10n.groupMemberNowMember(name));
      case _MemberAction.stepDown:
        final confirmed = await confirmDestructive(
          context,
          title: l10n.groupStepDownTitle,
          body: l10n.groupStepDownBody,
          confirmLabel: l10n.groupStepDown,
        );
        if (!confirmed || !context.mounted) return;
        await setRole(GroupRole.member, l10n.groupSteppedDown);
      case _MemberAction.remove:
        final confirmed = await confirmDestructive(
          context,
          title: l10n.groupMemberRemoveTitle(name),
          body:
              '${l10n.groupMemberRemoveBody(name)} '
              '${l10n.groupMemberRemoveGamesBody(name)}',
          confirmLabel: l10n.groupMemberRemoveConfirm,
        );
        if (!confirmed || !context.mounted) return;
        final (gamesLeft, error) = await actions.removeMember(
          groupId: groupId,
          userId: member.userId,
        );
        if (!context.mounted) return;
        if (error == null) {
          showSnack(
            context,
            gamesLeft > 0
                ? l10n.groupMemberRemovedWithGames(name, gamesLeft)
                : l10n.groupMemberRemoved(name),
          );
        } else if (blocked != null && opensBlockedSheet(error)) {
          await blocked!(context, error, name: name);
        } else {
          showErrorSnack(context, error);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myId = ref.watch(sessionUserIdProvider);
    final iAmAdmin = members.any(
      (m) => m.userId == myId && m.role == GroupRole.admin,
    );
    final sorted = [...members]
      ..sort((a, b) {
        if (a.role != b.role) return a.role == GroupRole.admin ? -1 : 1;
        return compareNames(a.displayName, b.displayName);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        ListCard(
          children: [
            for (final member in sorted)
              _row(context, ref, l10n, member, myId, iAmAdmin),
          ],
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GroupMember member,
    String? myId,
    bool iAmAdmin,
  ) {
    final isMe = member.userId == myId;
    // O membro comum não toca na própria linha.
    final tappable = iAmAdmin || !isMe;
    return ListRow(
      leading: PersonAvatarView(
        id: member.userId,
        name: member.displayName,
        photoPath: member.photoPath,
        isYou: isMe,
      ),
      title: isMe
          ? l10n.groupMemberYou(member.displayName)
          : member.displayName,
      badge: member.role == GroupRole.admin
          ? VoleiBadge.neutral(context, l10n.groupRoleAdmin)
          : null,
      subtitle: l10n.groupMemberJoinedAt(formatDate(member.joinedAt)),
      onTap: tappable
          ? () => _onTap(
              context,
              ref,
              member: member,
              isMe: isMe,
              iAmAdmin: iAmAdmin,
            )
          : null,
    );
  }
}
