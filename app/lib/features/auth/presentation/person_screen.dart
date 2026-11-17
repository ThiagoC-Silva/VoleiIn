import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format/phone.dart';
import '../../../core/link_opener.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/icon_square.dart';
import '../../../shared/widgets/snack.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/profile.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

/// Perfil de outra pessoa (RF19, RN107; docs/ui/telas.md, 6.9; person.png).
/// Abre na aba de origem, com a barra inferior. Sem contexto, ou com um ID
/// que não existe, o estado "não encontrado", sem dizer qual dos dois. A
/// fatia 4 acrescenta o telefone visível (RF101).
class PersonScreen extends ConsumerWidget {
  const PersonScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personProvider(userId));
    return Scaffold(
      appBar: const InnerAppBar(title: ''),
      body: switch (person) {
        AsyncValue(:final value?) => _PersonBody(profile: value),
        AsyncError(:final error) => ErrorStateView(
          error: error,
          onRetry: () => ref.invalidate(personProvider(userId)),
        ),
        _ => const LoadingState(),
      },
    );
  }
}

class _PersonBody extends ConsumerWidget {
  const _PersonBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final path = profile.photoPath;
    final photoUrl = path == null
        ? null
        : ref.watch(avatarUrlProvider(path)).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: VoleiAvatar(
              id: profile.id,
              name: profile.displayName,
              size: 96,
              imageUrl: photoUrl,
              isYou: profile.id == ref.watch(sessionUserIdProvider),
            ),
          ),
          const SizedBox(height: 16),
          // O nome exibido (RN100) e, só quando há apelido, o nome embaixo.
          Text(
            profile.displayName,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (profile.nickname != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          _PhoneSection(userId: profile.id),
        ],
      ),
    );
  }
}

/// A linha Telefone, com Ligar e WhatsApp, só quando `get_profile_contact`
/// devolve o número (RF101, RN101; telas.md, 7.9; person-telefone.png).
class _PhoneSection extends ConsumerWidget {
  const _PhoneSection({required this.userId});

  final String userId;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(linkOpenerProvider).open(uri);
    if (!opened && context.mounted) {
      showSnack(context, AppLocalizations.of(context).commonCannotOpenLink);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(personPhoneProvider(userId)).value;
    if (phone == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const IconSquare(icon: Symbols.call),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.personPhone,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatPhone(phone),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _open(context, ref, phoneCallUri(phone)),
                icon: const Icon(Symbols.call),
                label: Text(l10n.personCall),
              ),
              OutlinedButton.icon(
                onPressed: () => _open(context, ref, phoneWhatsappUri(phone)),
                icon: const Icon(Symbols.chat),
                label: Text(l10n.personWhatsapp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
