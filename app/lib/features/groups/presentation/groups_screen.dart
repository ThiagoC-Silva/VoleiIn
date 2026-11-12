import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';

/// Meus grupos (RF25). A tela real chega na fatia 3.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RootTabScaffold(
      title: l10n.navGroups,
      body: PlaceholderTab(
        icon: Symbols.groups,
        title: l10n.placeholderTitle,
        body: l10n.placeholderBody,
      ),
    );
  }
}
