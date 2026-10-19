import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo do código de seis dígitos, com reenvio liberado depois do intervalo mínimo
/// entre envios. O intervalo é imposto pelo servidor (max_frequency); a contagem aqui
/// só evita um toque que seria recusado.
class EtapaCodigo extends StatefulWidget {
  const EtapaCodigo({
    super.key,
    required this.destino,
    required this.ocupado,
    required this.aoConfirmar,
    required this.aoReenviar,
  });

  static const intervaloReenvio = Duration(seconds: 60);

  final String destino;
  final bool ocupado;
  final void Function(String codigo) aoConfirmar;
  final Future<void> Function() aoReenviar;

  @override
  State<EtapaCodigo> createState() => _EtapaCodigoState();
}

class _EtapaCodigoState extends State<EtapaCodigo> {
  final _codigo = TextEditingController();
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
    _codigo.dispose();
    super.dispose();
  }

  void _contar() {
    _relogio?.cancel();
    setState(() => _segundos = EtapaCodigo.intervaloReenvio.inSeconds);
    _relogio = Timer.periodic(const Duration(seconds: 1), (relogio) {
      setState(() => _segundos--);
      if (_segundos <= 0) relogio.cancel();
    });
  }

  Future<void> _reenviar() async {
    _codigo.clear();
    await widget.aoReenviar();
    if (mounted) _contar();
  }

  void _confirmar() {
    if (_codigo.text.length == 6) widget.aoConfirmar(_codigo.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enviamos um código de 6 dígitos para ${widget.destino}. Ele vale por 5 minutos.'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('campo-codigo'),
          controller: _codigo,
          autofocus: true,
          enabled: !widget.ocupado,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Código'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirmar(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: widget.ocupado || _codigo.text.length != 6 ? null : _confirmar,
          child: const Text('Confirmar'),
        ),
        TextButton(
          onPressed: widget.ocupado || _segundos > 0 ? null : _reenviar,
          child: Text(_segundos > 0 ? 'Reenviar código em $_segundos s' : 'Reenviar código'),
        ),
      ],
    );
  }
}
