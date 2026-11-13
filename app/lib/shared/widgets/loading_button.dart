import 'package:flutter/material.dart';

/// Botão principal que troca o texto por um indicador enquanto envia e
/// bloqueia novo toque (design-system.md, 7.1, "Carregando").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label, textAlign: TextAlign.center),
    );
  }
}
