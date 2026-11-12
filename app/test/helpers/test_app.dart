import 'package:flutter/material.dart';
import 'package:voleiin/core/theme/app_theme.dart';
import 'package:voleiin/l10n/app_localizations.dart';

/// Monta o `MaterialApp` com o tema e a localização do app
/// (docs/arquitetura-app.md, seção 12).
class TestApp extends StatelessWidget {
  const TestApp({required this.child, this.textScale = 1.0, super.key});

  final Widget child;

  /// 1.5 cobre a fonte do sistema em 150% (RNF05, cenário L04).
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: child,
    );
  }
}

/// Textos do `app_pt.arb`, para o teste comparar com o que a tela mostra.
AppLocalizations get l10nPt => lookupAppLocalizations(const Locale('pt'));
