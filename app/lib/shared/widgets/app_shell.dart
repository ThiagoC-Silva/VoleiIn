import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import 'bottom_nav.dart';

/// Casca das quatro abas (docs/ui/telas.md, 2.1 e 3.2).
///
/// A barra troca de aba sem empilhar e guarda a posição de cada uma. O voltar do
/// Android numa raiz que não é Jogos vai para Jogos; em Jogos, fecha o app.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onGamesTab = navigationShell.currentIndex == 0;

    return PopScope(
      canPop: onGamesTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: VoleiBottomNav(
          currentIndex: navigationShell.currentIndex,
          onSelected: (index) => navigationShell.goBranch(
            index,
            // Tocar na aba atual volta à raiz dela.
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavDestinationData(icon: Symbols.sports_volleyball, label: l10n.navGames),
            NavDestinationData(icon: Symbols.groups, label: l10n.navGroups),
            // O contador vermelho de Cobranças entra na fatia 5, com os valores.
            NavDestinationData(icon: Symbols.payments, label: l10n.navCharges),
            NavDestinationData(icon: Symbols.person, label: l10n.navProfile),
          ],
        ),
      ),
    );
  }
}
