import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/tema.dart';
import '../../core/widgets/botao_primario.dart';
import '../../core/widgets/campo_codigo.dart';
import '../../core/widgets/mensagem_erro.dart';
import '../../core/widgets/reenvio_codigo.dart';
import '../../core/widgets/topo_interno.dart';
import 'execucao_auth.dart';

/// A3 — Confirmar e-mail (RN21): o código de seis dígitos conclui o cadastro, e o
/// perfil nasce nesse instante, pelo gatilho do banco.
class ConfirmarEmailTela extends ConsumerStatefulWidget {
  const ConfirmarEmailTela({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ConfirmarEmailTela> createState() => _ConfirmarEmailTelaState();
}

class _ConfirmarEmailTelaState extends ConsumerState<ConfirmarEmailTela> with ExecucaoAuth {
  final _codigo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codigo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  bool get _completo => _codigo.text.length == CampoCodigo.tamanho;

  // A sessão nasce na confirmação, e a raiz troca a entrada pelo início por baixo
  // desta pilha; por isso a pilha é desfeita até a raiz.
  void _confirmar() async {
    if (!_completo) return;
    if (await executar((repositorio) => repositorio.confirmarCadastro(widget.email, _codigo.text)) &&
        mounted) {
      Navigator.of(context).popUntil((rota) => rota.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = VoleiCores.of(context);
    final estilo = tema.textTheme.bodyLarge!.copyWith(fontSize: 18);
    return Scaffold(
      appBar: TopoInterno(titulo: 'Confirmar e-mail', habilitado: !ocupado),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: cores.jogo, borderRadius: BorderRadius.circular(16)),
                child: Icon(Symbols.mark_email_unread_rounded, size: 28, color: cores.sobreBloco),
              ),
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: 'Enviamos um código de 6 dígitos para ',
                children: [
                  TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '. Ele vale por 5 minutos.'),
                ],
              ),
              style: estilo,
            ),
            const SizedBox(height: 24),
            CampoCodigo(controller: _codigo, habilitado: !ocupado, aoEnviar: _confirmar),
            const SizedBox(height: 24),
            if (erro != null) ...[
              MensagemErro(erro!),
              const SizedBox(height: 16),
            ],
            BotaoPrimario(texto: 'Confirmar', ocupado: ocupado, aoTocar: _completo ? _confirmar : null),
            const SizedBox(height: 24),
            Center(
              child: ReenvioCodigo(
                ocupado: ocupado,
                aoReenviar: () => executar((repositorio) async {
                  _codigo.clear();
                  await repositorio.reenviarConfirmacao(widget.email);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
