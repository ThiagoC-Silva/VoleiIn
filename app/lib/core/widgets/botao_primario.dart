import 'package:flutter/material.dart';

/// O botão amarelo, um por tela. Ocupado, troca o texto por um indicador e não aceita toque.
class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({super.key, required this.texto, required this.aoTocar, this.ocupado = false});

  final String texto;

  /// Nulo deixa o botão desabilitado.
  final VoidCallback? aoTocar;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: ocupado ? null : aoTocar,
      child: ocupado
          ? SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Text(texto),
    );
  }
}
