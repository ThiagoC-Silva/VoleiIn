import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/botao_primario.dart';
import '../../core/widgets/campo_texto.dart';
import '../../core/widgets/mensagem_erro.dart';
import '../../core/widgets/topo_interno.dart';
import '../../dados/auth_repositorio.dart';
import 'confirmar_email_tela.dart';
import 'execucao_auth.dart';

/// A2 — Criar conta (RF01, RN21): nome, e-mail e senha. A conta fica pendente até o
/// código da A3, que toma o lugar desta tela: voltar de lá leva à entrada.
class CriarContaTela extends ConsumerStatefulWidget {
  const CriarContaTela({super.key, this.email = ''});

  /// O que já tinha sido digitado na entrada.
  final String email;

  @override
  ConsumerState<CriarContaTela> createState() => _CriarContaTelaState();
}

class _CriarContaTelaState extends ConsumerState<CriarContaTela> with ExecucaoAuth {
  final _nome = TextEditingController();
  late final _email = TextEditingController(text: widget.email);
  final _senha = TextEditingController();

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  String get _emailDigitado => _email.text.trim().toLowerCase();

  bool get _valido =>
      _nome.text.trim().isNotEmpty &&
      _emailDigitado.contains('@') &&
      _senha.text.length >= tamanhoMinimoSenha;

  void _criar() {
    if (!_valido) return;
    final email = _emailDigitado;
    executar((repositorio) async {
      await repositorio.criarConta(_nome.text.trim(), email, _senha.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ConfirmarEmailTela(email: email)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    void mudou(String _) => setState(() {});
    return Scaffold(
      appBar: TopoInterno(titulo: 'Criar conta', habilitado: !ocupado),
      body: SafeArea(
        top: false,
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text('Como a turma vai te ver?', style: tema.textTheme.bodyLarge!.copyWith(fontSize: 18)),
              const SizedBox(height: 24),
              CampoTexto(
                rotulo: 'Nome',
                chave: const Key('campo-nome'),
                controller: _nome,
                autofocus: true,
                habilitado: !ocupado,
                capitalizacao: TextCapitalization.words,
                preenchimento: const [AutofillHints.name],
                acao: TextInputAction.next,
                aoMudar: mudou,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                rotulo: 'E-mail',
                chave: const Key('campo-email'),
                controller: _email,
                habilitado: !ocupado,
                teclado: TextInputType.emailAddress,
                preenchimento: const [AutofillHints.email],
                acao: TextInputAction.next,
                aoMudar: mudou,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                rotulo: 'Senha',
                chave: const Key('campo-senha'),
                controller: _senha,
                senha: true,
                habilitado: !ocupado,
                dica: 'Mínimo de $tamanhoMinimoSenha caracteres.',
                preenchimento: const [AutofillHints.newPassword],
                acao: TextInputAction.done,
                aoMudar: mudou,
                aoEnviar: (_) => _criar(),
              ),
              const SizedBox(height: 24),
              if (erro != null) ...[
                MensagemErro(erro!),
                const SizedBox(height: 16),
              ],
              BotaoPrimario(texto: 'Criar conta', ocupado: ocupado, aoTocar: _valido ? _criar : null),
              const SizedBox(height: 16),
              Text(
                'Enviamos um código de 6 dígitos para confirmar o e-mail. A conta só existe depois dele.',
                style: tema.textTheme.bodyLarge!.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
