import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dados/auth_repositorio.dart';
import 'etapa_codigo.dart';

enum _Etapa { email, nome, codigo }

/// Entrar e criar conta numa tela só (RF01, RN21): e-mail, nome só quando o e-mail
/// ainda não tem conta, e o código. Ao confirmar, a sessão muda e a raiz troca a tela.
class EntrarTela extends ConsumerStatefulWidget {
  const EntrarTela({super.key});

  @override
  ConsumerState<EntrarTela> createState() => _EntrarTelaState();
}

class _EntrarTelaState extends ConsumerState<EntrarTela> {
  final _email = TextEditingController();
  final _nome = TextEditingController();
  var _etapa = _Etapa.email;
  var _contaNova = false;
  var _ocupado = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _nome.dispose();
    super.dispose();
  }

  String get _emailDigitado => _email.text.trim().toLowerCase();

  Future<void> _executar(Future<void> Function(AuthRepositorio repositorio) acao) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao(ref.read(authRepositorioProvider));
    } on FalhaAuth catch (falha) {
      if (mounted) setState(() => _erro = falha.mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  void _continuarEmail() {
    if (!_emailDigitado.contains('@')) {
      setState(() => _erro = 'Confira o e-mail digitado.');
      return;
    }
    _executar((repositorio) async {
      final existe = await repositorio.pedirCodigo(_emailDigitado);
      setState(() {
        _contaNova = !existe;
        _etapa = existe ? _Etapa.codigo : _Etapa.nome;
      });
    });
  }

  void _continuarNome() {
    if (_nome.text.trim().isEmpty) {
      setState(() => _erro = 'Informe como a turma vai te ver.');
      return;
    }
    _executar((repositorio) async {
      await repositorio.criarConta(_emailDigitado, _nome.text.trim());
      setState(() => _etapa = _Etapa.codigo);
    });
  }

  Future<void> _reenviar() => _executar((repositorio) async {
        if (_contaNova) {
          await repositorio.criarConta(_emailDigitado, _nome.text.trim());
        } else {
          await repositorio.pedirCodigo(_emailDigitado);
        }
      });

  void _voltar() => setState(() {
        _etapa = _Etapa.email;
        _erro = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar no VoleiIn'),
        leading: _etapa == _Etapa.email
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Trocar e-mail',
                onPressed: _ocupado ? null : _voltar,
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            switch (_etapa) {
              _Etapa.email => _etapaEmail(),
              _Etapa.nome => _etapaNome(),
              _Etapa.codigo => EtapaCodigo(
                  destino: _emailDigitado,
                  ocupado: _ocupado,
                  aoConfirmar: (codigo) => _executar(
                    (repositorio) => repositorio.confirmarCodigo(_emailDigitado, codigo),
                  ),
                  aoReenviar: _reenviar,
                ),
            },
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

  Widget _etapaEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Informe seu e-mail. Vamos enviar um código para você entrar.'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('campo-email'),
          controller: _email,
          autofocus: true,
          enabled: !_ocupado,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'E-mail'),
          onSubmitted: (_) => _continuarEmail(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _ocupado ? null : _continuarEmail,
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _etapaNome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$_emailDigitado ainda não tem conta. Como a turma vai te ver?'),
        const SizedBox(height: 16),
        TextField(
          key: const Key('campo-nome'),
          controller: _nome,
          autofocus: true,
          enabled: !_ocupado,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (_) => _continuarNome(),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _ocupado ? null : _continuarNome,
          child: const Text('Criar conta'),
        ),
      ],
    );
  }
}
