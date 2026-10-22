import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Erro que não pertence a um campo, como a recusa do serviço: ícone e texto, nunca só cor.
class MensagemErro extends StatelessWidget {
  const MensagemErro(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.error_rounded, size: 20, color: tema.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: tema.textTheme.bodyMedium!.copyWith(color: tema.colorScheme.error)),
        ),
      ],
    );
  }
}
