import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/errors/error_code.dart';
import '../../core/errors/error_text.dart';
import '../../l10n/app_localizations.dart';

// Estados de tela (docs/ui/design-system.md, 7.16). Toda tela tem os quatro.

/// Carregando: indicador em `primary`, centralizado.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Vazio: ícone num quadrado, título, uma frase e, se houver, o botão da ação.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Erro e sem conexão: mesmo formato do vazio, com "Tentar de novo".
/// Sem conexão é o caso de [ErrorCode.noConnection] (RNF07).
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = error;
    final offline =
        failure is AppException && failure.code == ErrorCode.noConnection;
    return EmptyState(
      icon: offline ? Symbols.wifi_off : Symbols.error_outline,
      title: errorTextFor(l10n, error),
      body: '',
      action: OutlinedButton(onPressed: onRetry, child: Text(l10n.commonTryAgain)),
    );
  }
}
