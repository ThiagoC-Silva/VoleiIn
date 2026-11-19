import 'package:flutter/material.dart';

/// Tela-raiz de aba: barra superior de raiz com o título
/// (docs/ui/design-system.md, 7.7) e o corpo da aba.
///
/// O sino entra na fatia 7.
class RootTabScaffold extends StatelessWidget {
  const RootTabScaffold({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A barra cresce com a fonte do sistema: com o título em title.xl (28) a
    // 150%, uma altura fixa cortaria o texto (RNF05).
    final titleHeight = MediaQuery.textScalerOf(context).scale(28 * 1.25);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: theme.textTheme.headlineLarge),
        toolbarHeight: 32 + titleHeight,
      ),
      body: body,
    );
  }
}
