import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/format/date_time.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/group_models.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';
import 'groups_providers.dart';

/// Solicitações (RF17; docs/ui/telas.md, 6.7; groupRequests.png). Só para
/// admins: a tela confere o papel antes de mostrar o conteúdo.
class GroupRequestsScreen extends ConsumerWidget {
  const GroupRequestsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final group = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      appBar: InnerAppBar(title: l10n.groupRequests),
      body: switch (group) {
        AsyncValue(:final value?) when !value.isAdmin => ErrorStateView(
          error: const AppException(ErrorCode.notFound),
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        AsyncValue(hasValue: true) => _Requests(groupId: groupId),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _Requests extends ConsumerStatefulWidget {
  const _Requests({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_Requests> createState() => _RequestsState();
}

class _RequestsState extends ConsumerState<_Requests> {
  /// Solicitação enviando e o botão tocado. Só a linha dela fica bloqueada.
  final _busy = <String, bool>{};

  Future<void> _decide(JoinRequest request, {required bool approve}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy[request.id] = approve);
    final error = await ref
        .read(groupActionsControllerProvider.notifier)
        .decideRequest(
          groupId: widget.groupId,
          requestId: request.id,
          approve: approve,
        );
    if (!mounted) return;
    setState(() => _busy.remove(request.id));
    if (error != null) {
      showErrorSnack(context, error);
    } else {
      showSnack(
        context,
        approve
            ? l10n.groupRequestApproved(request.displayName)
            : l10n.groupRequestRejected,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(groupRequestsProvider(widget.groupId));
    // Mantém o controller vivo enquanto a tela estiver aberta.
    ref.watch(groupActionsControllerProvider);
    Future<void> refresh() =>
        ref.refresh(groupRequestsProvider(widget.groupId).future);

    return switch (requests) {
      AsyncValue(:final value?) when value.isEmpty => RefreshIndicator(
        onRefresh: refresh,
        child: EmptyState(
          icon: Symbols.person_add,
          title: l10n.groupRequestsEmptyTitle,
          body: l10n.groupRequestsEmptyBody,
        ),
      ),
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          children: [
            // Das mais antigas para as mais novas.
            for (final request in [
              ...value,
            ]..sort((a, b) => a.createdAt.compareTo(b.createdAt))) ...[
              _RequestCard(
                request: request,
                busy: _busy.containsKey(request.id),
                approving: _busy[request.id] == true,
                onApprove: () => _decide(request, approve: true),
                onReject: () => _decide(request, approve: false),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      AsyncError(:final error) => ErrorStateView(
        error: error,
        onRetry: () => ref.invalidate(groupRequestsProvider(widget.groupId)),
      ),
      _ => const LoadingState(),
    };
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.approving,
    required this.onApprove,
    required this.onReject,
  });

  final JoinRequest request;
  final bool busy;
  final bool approving;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    void openProfile() => context.pushNamed(
      Routes.person,
      pathParameters: {'userId': request.userId},
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tocar no avatar ou no nome abre o perfil (RN107, exceção 2).
            InkWell(
              onTap: openProfile,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    PersonAvatarView(
                      id: request.userId,
                      name: request.displayName,
                      photoPath: request.photoPath,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.groupRequestAsked(
                              formatShortDate(request.createdAt),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: busy && !approving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            l10n.groupRequestReject,
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: l10n.groupRequestApprove,
                    loading: busy && approving,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
