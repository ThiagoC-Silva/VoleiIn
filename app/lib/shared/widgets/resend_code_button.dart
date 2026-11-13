import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import 'snack.dart';

/// Reenviar código (docs/ui/telas.md, regras comuns da seção 5): desabilitado
/// por 60 s depois de cada envio, com a contagem no rótulo. A espera é só da
/// tela: quem limita os envios de verdade é o Supabase Auth.
///
/// A contagem começa ao abrir, porque a tela abre logo depois de um envio.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({required this.onResend, super.key});

  static const wait = 60;

  /// Pede o código novo. Lança `AppException` na falha, que vira `SnackBar`.
  final Future<void> Function() onResend;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _remaining = ResendCodeButton.wait;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _remaining = ResendCodeButton.wait;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await widget.onResend();
      if (!mounted) return;
      setState(_start);
      showSnack(context, l10n.authCodeResent);
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final waiting = _remaining > 0;
    return Center(
      child: TextButton.icon(
        onPressed: waiting || _sending ? null : _resend,
        icon: const Icon(Symbols.schedule, size: 22),
        label: Text(
          waiting ? l10n.authResendCodeIn(_remaining) : l10n.authResendCode,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
