import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/botao_primario.dart';
import '../../core/widgets/campo_codigo.dart';
import '../../core/widgets/mensagem_erro.dart';
import '../../core/widgets/reenvio_codigo.dart';
import '../../dados/auth_repositorio.dart';
import '../auth/execucao_auth.dart';

/// Troca de e-mail (RF35, RN21): código no endereço novo, aviso no antigo, e as
/// sessões dos outros aparelhos caem ao confirmar (RNF07).
/// O desenho da H3 ainda não foi aplicado; só o código já usa as casas do design.
class TrocarEmailTela extends ConsumerStatefulWidget {
  const TrocarEmailTela({super.key});

  @override
  ConsumerState<TrocarEmailTela> createState() => _TrocarEmailTelaState();
}

class _TrocarEmailTelaState extends ConsumerState<TrocarEmailTela> with ExecucaoAuth {
  final _novo = TextEditingController();
  final _codigo = TextEditingController();
  var _codigoEnviado = false;

  @override
  void initState() {
    super.initState();
    _codigo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _novo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  String get _novoDigitado => _novo.text.trim().toLowerCase();

  void _pedir() async {
    if (!_novoDigitado.contains('@')) {
      setState(() => erro = 'Confira o e-mail digitado.');
      return;
    }
    if (_novoDigitado == ref.read(authRepositorioProvider).emailAtual) {
      setState(() => erro = 'Esse já é o e-mail da sua conta.');
      return;
    }
    if (await executar((repositorio) => repositorio.pedirTrocaEmail(_novoDigitado))) {
      setState(() => _codigoEnviado = true);
    }
  }

  void _confirmar() async {
    if (_codigo.text.length != CampoCodigo.tamanho) return;
    if (await executar((repositorio) => repositorio.confirmarTrocaEmail(_novoDigitado, _codigo.text))) {
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
                enabled: !ocupado,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail novo'),
                onSubmitted: (_) => _pedir(),
              ),
              const SizedBox(height: 16),
              BotaoPrimario(texto: 'Enviar código', ocupado: ocupado, aoTocar: _pedir),
            ] else ...[
              Text('Enviamos um código de 6 dígitos para $_novoDigitado. Ele vale por 5 minutos.'),
              const SizedBox(height: 24),
              CampoCodigo(controller: _codigo, habilitado: !ocupado, aoEnviar: _confirmar),
              const SizedBox(height: 24),
              BotaoPrimario(
                texto: 'Confirmar',
                ocupado: ocupado,
                aoTocar: _codigo.text.length == CampoCodigo.tamanho ? _confirmar : null,
              ),
              const SizedBox(height: 24),
              Center(
                child: ReenvioCodigo(
                  ocupado: ocupado,
                  aoReenviar: () => executar((repositorio) async {
                    _codigo.clear();
                    await repositorio.pedirTrocaEmail(_novoDigitado);
                  }),
                ),
              ),
            ],
            if (erro != null) ...[
              const SizedBox(height: 16),
              MensagemErro(erro!),
            ],
          ],
        ),
      ),
    );
  }
}
