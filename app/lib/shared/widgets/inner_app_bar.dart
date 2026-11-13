import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router/routes.dart';
import '../../l10n/app_localizations.dart';

/// Barra superior interna: botão circular de voltar e título `title.md`
/// (design-system.md, 7.7). Sem [onBack], o voltar desempilha a tela; se não
/// houver o que desempilhar, vai para o login.
class InnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const InnerAppBar({
    required this.title,
    this.onBack,
    this.showBack = true,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final bool showBack;

  /// A altura cresce com a fonte do sistema no `build`; esta é a base.
  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final titleHeight = MediaQuery.textScalerOf(context).scale(18 * 1.3);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: titleHeight < 48 ? 72 : 24 + titleHeight,
      titleSpacing: showBack ? 4 : 24,
      leadingWidth: showBack ? 72 : 0,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: IconButton(
                  tooltip: l10n.commonBack,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Symbols.arrow_back),
                  onPressed: onBack ?? () => _defaultBack(context),
                ),
              ),
            )
          : null,
      title: Text(title, style: theme.textTheme.titleLarge, maxLines: 2),
    );
  }

  static void _defaultBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Routes.login);
    }
  }
}
