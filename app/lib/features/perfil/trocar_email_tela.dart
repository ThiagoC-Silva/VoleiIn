import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/auth_repositorio.dart';
import '../auth/etapa_codigo.dart';

/// Troca de e-mail (RF35, RN21): código no endereço novo, aviso no antigo, e as
/// sessões dos outros aparelhos caem ao confirmar (RNF07).
class TrocarEmailTela extends ConsumerStatefulWidget {
  const TrocarEmailTela({super.key});

  @override
  ConsumerState<TrocarEmailTela> createState() => _TrocarEmailTelaState();
}

class _TrocarEmailTelaState extends ConsumerState<TrocarEmailTela> {
  final _novo = TextEditingController();
  var _codigoEnviado = false;
  var _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _novo.dispose();
    super.dispose();
  }

  String get _novoDigitado => _novo.text.trim().toLowerCase();

  Future<bool> _executar(Future<void> Function(AuthRepositorio repositorio) acao) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao(ref.read(authRepositorioProvider));
      return true;
    } on FalhaAuth catch (falha) {
      if (mounted) setState(() => _erro = falha.mensagem);
      return false;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _pedir() async {
    if (!_novoDigitado.contains('@')) {
      setState(() => _erro = 'Confira o e-mail digitado.');
      return;
    }
    if (_novoDigitado == ref.read(authRepositorioProvider).emailAtual) {
      setState(() => _erro = 'Esse já é o e-mail da sua conta.');
      return;
    }
    if (await _executar((repositorio) => repositorio.pedirTrocaEmail(_novoDigitado))) {
      setState(() => _codigoEnviado = true);
    }
  }

  void _confirmar(String codigo) async {
    if (await _executar((repositorio) => repositorio.confirmarTrocaEmail(_novoDigitado, codigo))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail trocado. Os outros aparelhos foram desconectados.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final atual = ref.watch(authRepositorioProvider).emailAtual ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Trocar e-mail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_codigoEnviado) ...[
              Text('Hoje você entra com $atual. Depois da troca, $atual recebe um aviso, '
                  'e os outros aparelhos em que você está conectado saem da conta.'),
              const SizedBox(height: 16),
              TextField(
                key: const Key('campo-email-novo'),
                controller: _novo,
                autofocus: true,
                enabled: !_ocupado,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail novo'),
                onSubmitted: (_) => _pedir(),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _ocupado ? null : _pedir,
                child: const Text('Enviar código'),
              ),
            ] else
              EtapaCodigo(
                destino: _novoDigitado,
                ocupado: _ocupado,
                aoConfirmar: _confirmar,
                aoReenviar: () => _executar((repositorio) => repositorio.pedirTrocaEmail(_novoDigitado)),
              ),
            if (_erro != null) ...[
              const SizedBox(height: 16),
              Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_ocupado) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
