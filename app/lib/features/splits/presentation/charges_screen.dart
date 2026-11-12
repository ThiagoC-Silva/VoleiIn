import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/root_tab_scaffold.dart';

/// Totais a pagar e a receber (RF75, RF76). As telas reais chegam nas fatias 5 e 6.
class ChargesScreen extends StatelessWidget {
  const ChargesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RootTabScaffold(
      title: l10n.navCharges,
      body: PlaceholderTab(
        icon: Symbols.payments,
        title: l10n.placeholderTitle,
        body: l10n.placeholderBody,
      ),
    );
  }
}
