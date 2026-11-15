import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ],
      ),
    );
  }
}
