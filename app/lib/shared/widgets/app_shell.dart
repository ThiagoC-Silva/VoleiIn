import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/games/presentation/games_providers.dart';
import '../../l10n/app_localizations.dart';
import 'bottom_nav.dart';

/// Casca das quatro abas (docs/ui/telas.md, 2.1 e 3.2).
///
/// A barra troca de aba sem empilhar e guarda a posição de cada uma. O voltar do
/// Android numa raiz que não é Jogos vai para Jogos; em Jogos, fecha o app.
/// A aba Cobranças tem o contador de valores Pendentes a pagar e relê ao ser
/// tocada (telas.md, 8.5).
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _chargesTab = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final onGamesTab = navigationShell.currentIndex == 0;
    final pending = ref.watch(myChargesProvider).value?.pendingToPayCount ?? 0;

    return PopScope(
      canPop: onGamesTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: VoleiBottomNav(
          currentIndex: navigationShell.currentIndex,
          onSelected: (index) {
            if (index == _chargesTab) ref.invalidate(myChargesProvider);
            navigationShell.goBranch(
              index,
              // Tocar na aba atual volta à raiz dela.
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavDestinationData(
              icon: Symbols.sports_volleyball,
              label: l10n.navGames,
            ),
            NavDestinationData(icon: Symbols.groups, label: l10n.navGroups),
            NavDestinationData(
              icon: Symbols.payments,
              label: l10n.navCharges,
              badgeCount: pending,
              badgeLabel: l10n.chargesTabBadgeLabel(pending),
            ),
            NavDestinationData(icon: Symbols.person, label: l10n.navProfile),
          ],
        ),
      ),
    );
  }
}
