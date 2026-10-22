import 'package:flutter/material.dart';

import '../tema.dart';

/// Aviso dentro da tela: card de superfície com o quadrado de ícone na cor do assunto.
class AvisoInline extends StatelessWidget {
  const AvisoInline({super.key, required this.icone, required this.cor, required this.texto});

  final IconData icone;
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(13)),
            child: Icon(icone, size: 22, color: VoleiCores.of(context).sobreBloco),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(texto, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
