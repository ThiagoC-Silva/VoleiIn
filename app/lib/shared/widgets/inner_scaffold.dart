import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Tela interna: barra com o botão circular de voltar e o título `title.md`
/// (design-system.md, 7.7). O corpo rola e pode ter botões fixos no pé.
class InnerScaffold extends StatelessWidget {
  const InnerScaffold({
    required this.title,
    required this.body,
    this.footer,
    this.onBack,
    super.key,
  });

  final String title;
  final Widget body;

  /// Botões presos ao pé da tela (profileEdit.png, profilePix.png).
  final Widget? footer;

  /// Voltar próprio (por exemplo, da etapa 2 para a etapa 1).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleHeight = MediaQuery.textScalerOf(context).scale(18 * 1.3);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 32 + (titleHeight > 48 ? titleHeight : 48),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(48, 48),
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Symbols.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        title: Text(title, style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: body,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho das telas de acesso sem barra: quadrado amarelo com ícone, título
/// `title.xl` e frase de apoio (confirmEmail.png, terms.png).
class AccessHeader extends StatelessWidget {
  const AccessHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final Widget title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimary, size: 28),
        ),
        const SizedBox(height: 24),
        DefaultTextStyle.merge(
          style: theme.textTheme.headlineLarge,
          child: title,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 16),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyLarge,
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}
