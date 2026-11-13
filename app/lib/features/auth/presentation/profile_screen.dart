import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/arrow_rows.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../domain/own_profile.dart';
import '../domain/pix_key.dart';
import 'pix_key_label.dart';
import 'profile_providers.dart';

/// Meu perfil (RF07 a RF12, RF106, RF107; docs/ui/telas.md, 5.7; profile.png e
/// profile-google.png).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(ownProfileProvider);
    return RootTabScaffold(
      title: l10n.navProfile,
      body: profile.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
        data: (own) => _ProfileView(own: own),
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.own});

  final OwnProfile own;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      // Sem confirmação (telas.md, 5.7). O roteador volta ao login.
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (context.mounted) showErrorSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(authRepositoryProvider);
    final profile = own.profile;
    final private = own.private;
    final photoUrl = profile.photoPath == null
        ? null
        : ref.watch(avatarUrlProvider(profile.photoPath!)).value;

    final pixType = private.pixKeyType;
    final pixKey = private.pixKey;
    final pixSubtitle = pixType == null || pixKey == null
        ? l10n.profilePixNone
        : l10n.profilePixSummary(
            pixKeyTypeLabel(l10n, pixType),
            formatPixKey(pixType, pixKey),
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            VoleiAvatar(
              id: profile.id,
              name: profile.displayName,
              size: 72,
              imageUrl: photoUrl,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.currentEmail ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ArrowRowGroup(
          rows: [
            ArrowRow(
              icon: Symbols.edit,
              title: l10n.profileEdit,
              subtitle: l10n.profileEditSubtitle,
              onTap: () => context.pushNamed(Routes.profileEdit),
            ),
            ArrowRow(
              icon: Symbols.qr_code_2,
              title: l10n.profilePix,
              subtitle: pixSubtitle,
              onTap: () => context.pushNamed(Routes.profilePix),
            ),
            if (auth.hasEmailAccess) ...[
              ArrowRow(
                icon: Symbols.alternate_email,
                title: l10n.profileChangeEmail,
                onTap: () => context.pushNamed(Routes.profileEmail),
              ),
              ArrowRow(
                icon: Symbols.key,
                title: l10n.profileChangePassword,
                onTap: () => context.pushNamed(Routes.profilePassword),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => _signOut(context, ref),
          child: Text(l10n.authLogout),
        ),
      ],
    );
  }
}
