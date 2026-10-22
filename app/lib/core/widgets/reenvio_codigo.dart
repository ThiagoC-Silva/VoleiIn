import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Reenvio do código, liberado depois do intervalo mínimo entre envios. O intervalo é
/// imposto pelo servidor (max_frequency); a contagem aqui só evita um toque que seria
/// recusado. Começa a contar ao aparecer, porque o código acabou de ser enviado.
class ReenvioCodigo extends StatefulWidget {
  const ReenvioCodigo({super.key, required this.ocupado, required this.aoReenviar});

  static const intervalo = Duration(seconds: 60);

  final bool ocupado;
  final Future<void> Function() aoReenviar;

  @override
  State<ReenvioCodigo> createState() => _ReenvioCodigoState();
}

class _ReenvioCodigoState extends State<ReenvioCodigo> {
  Timer? _relogio;
  int _segundos = 0;

  @override
  void initState() {
    super.initState();
    _contar();
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  void _contar() {
    _relogio?.cancel();
    setState(() => _segundos = ReenvioCodigo.intervalo.inSeconds);
    _relogio = Timer.periodic(const Duration(seconds: 1), (relogio) {
      setState(() => _segundos--);
      if (_segundos <= 0) relogio.cancel();
    });
  }

  Future<void> _reenviar() async {
    await widget.aoReenviar();
    if (mounted) _contar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final contando = _segundos > 0;
    final cor = contando ? tema.colorScheme.onSurface : tema.colorScheme.primary;
    final estilo = tema.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500, color: cor);
    return Material(
      color: tema.colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: contando || widget.ocupado ? null : _reenviar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(contando ? Symbols.schedule_rounded : Symbols.refresh_rounded, size: 20, color: cor),
              const SizedBox(width: 8),
              if (contando)
                Text.rich(
                  TextSpan(
                    text: 'Reenviar código em ',
                    children: [
                      TextSpan(
                        text: '$_segundos s',
                        style: tema.textTheme.headlineSmall!.copyWith(
                          fontSize: 22,
                          color: tema.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  style: estilo,
                )
              else
                Text('Reenviar código', style: estilo),
            ],
          ),
        ),
      ),
    );
  }
}
