import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';

/// Meus jogos (RF44). A tela real chega na fatia 4.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RootTabScaffold(
      title: l10n.navGames,
      body: PlaceholderTab(
        icon: Symbols.sports_volleyball,
        title: l10n.placeholderTitle,
        body: l10n.placeholderBody,
      ),
    );
  }
}
