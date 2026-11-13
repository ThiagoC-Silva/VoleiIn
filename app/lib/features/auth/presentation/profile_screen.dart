import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/nav_row.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../domain/pix_key_type.dart';
import '../domain/profile.dart';
import 'pix_key_labels.dart';
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
      body: switch (profile) {
        AsyncData(:final value) => _ProfileView(data: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(ownProfileProvider),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.data});

  final OwnProfile data;

  /// Abre uma edição e relê o perfil na volta (telas.md, 5.7).
  Future<void> _open(BuildContext context, WidgetRef ref, String route) async {
    await context.pushNamed(route);
    ref.invalidate(ownProfileProvider);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Sem confirmação (telas.md, 5.7). O roteador volta ao login.
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorTextFor(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = data.profile;
    final private = data.private;
    final pixType = private.pixKeyType;
    final pixKey = private.pixKey;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProfilePhotoAvatar(profile: profile, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Apelido ou, sem ele, o nome (RN100).
                    Text(
                      profile.displayName,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.email,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          NavRowGroup(
            children: [
              NavRow(
                icon: Symbols.edit,
                title: l10n.profileEdit,
                subtitle: l10n.profileEditSubtitle,
                onTap: () => _open(context, ref, Routes.profileEdit),
              ),
              NavRow(
                icon: Symbols.qr_code_2,
                title: l10n.profilePix,
                subtitle: pixType != null && pixKey != null
                    ? l10n.profilePixSummary(
                        pixType.label(l10n),
                        pixType.format(pixKey),
                      )
                    : l10n.profilePixNone,
                onTap: () => _open(context, ref, Routes.profilePix),
              ),
              // Só para quem tem acesso por e-mail e senha (telas.md, 5.7).
              if (data.hasEmailPassword) ...[
                NavRow(
                  icon: Symbols.alternate_email,
                  title: l10n.profileChangeEmail,
                  onTap: () => _open(context, ref, Routes.profileEmail),
                ),
                NavRow(
                  icon: Symbols.key,
                  title: l10n.profileChangePassword,
                  onTap: () => _open(context, ref, Routes.profilePassword),
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
      ),
    );
  }
}

/// Avatar do próprio perfil, com a foto por URL assinada ou as iniciais.
class ProfilePhotoAvatar extends ConsumerWidget {
  const ProfilePhotoAvatar({
    required this.profile,
    required this.size,
    this.pickedImage,
    this.hidePhoto = false,
    super.key,
  });

  final Profile profile;
  final double size;

  /// Foto escolhida e ainda não salva.
  final ImageProvider? pickedImage;

  /// Foto removida e ainda não salva: mostra as iniciais.
  final bool hidePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = profile.photoPath;
    ImageProvider? image = pickedImage;
    if (image == null && !hidePhoto && path != null) {
      final url = ref.watch(photoUrlProvider(path)).value;
      if (url != null) image = NetworkImage(url);
    }
    return AppAvatar(
      id: profile.id,
      name: profile.name,
      size: size,
      image: image,
    );
  }
}
