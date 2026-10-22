import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Barra superior das telas internas: botão circular de voltar e o título.
class TopoInterno extends StatelessWidget implements PreferredSizeWidget {
  const TopoInterno({super.key, required this.titulo, this.habilitado = true});

  final String titulo;

  /// Falso enquanto a tela espera o serviço, para não sair no meio da chamada.
  final bool habilitado;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  backgroundColor: tema.colorScheme.surface,
                  disabledBackgroundColor: tema.colorScheme.surface,
                  foregroundColor: tema.colorScheme.onSurface,
                ),
                icon: const Icon(Symbols.arrow_back_rounded),
                onPressed: habilitado ? () => Navigator.of(context).maybePop() : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titulo, style: tema.textTheme.titleLarge)),
            ],
          ),
        ),
      ),
    );
  }
}
