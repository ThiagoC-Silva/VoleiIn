import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';

/// "Reenviar código", desabilitado por 60 s depois de cada envio, com a contagem
/// no rótulo (docs/ui/telas.md, seção 5). A espera é só da tela: quem limita os
/// envios de verdade é o Supabase Auth.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({required this.onResend, super.key});

  static const wait = Duration(seconds: 60);

  /// Devolve `true` quando o código foi reenviado, para reiniciar a contagem.
  final Future<bool> Function() onResend;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _remaining = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // A tela abre logo depois de um envio.
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _remaining = ResendCodeButton.wait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final ok = await widget.onResend();
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waiting = _remaining > 0;
    return Center(
      child: TextButton.icon(
        onPressed: waiting || _sending ? null : _resend,
        icon: Icon(waiting ? Symbols.schedule : Symbols.refresh),
        label: Text(
          waiting ? l10n.authResendCodeIn('$_remaining') : l10n.authResendCode,
        ),
      ),
    );
  }
}
