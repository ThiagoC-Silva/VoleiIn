import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';
import '../data/auth_repository.dart';

/// Meu perfil (RF07 a RF12). A tela real chega na fatia 2.
///
/// O botão Sair é provisório: encerra a sessão para trocar de usuário nos
/// testes, sem confirmação (docs/ui/telas.md, 4.2). O Sair definitivo, com a
/// remoção do token de push, vem nas fatias 2 e 7.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return RootTabScaffold(
      title: l10n.navProfile,
      body: PlaceholderTab(
        icon: Symbols.person,
        title: l10n.placeholderTitle,
        body: l10n.placeholderBody,
        footer: OutlinedButton(
          onPressed: () => _signOut(context, ref, l10n),
          child: Text(l10n.authLogout),
        ),
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(errorTextFor(l10n, error))));
    }
  }
}
