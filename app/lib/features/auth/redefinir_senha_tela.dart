import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/tema.dart';
import '../../core/widgets/aviso_inline.dart';
import '../../core/widgets/botao_primario.dart';
import '../../core/widgets/campo_codigo.dart';
import '../../core/widgets/campo_texto.dart';
import '../../core/widgets/mensagem_erro.dart';
import '../../core/widgets/reenvio_codigo.dart';
import '../../core/widgets/topo_interno.dart';
import '../../dados/auth_repositorio.dart';
import 'execucao_auth.dart';

/// A4 — Redefinir senha (RF41, RN21): código no e-mail e senha nova, num caminho só para
/// a senha esquecida e para a troca a partir da sessão. É também como quem entra só pelo
/// Google cria uma senha. A etapa do e-mail não foi desenhada; ver
/// docs/design/telas/01-acesso/implementacao.md.
class RedefinirSenhaTela extends ConsumerStatefulWidget {
  const RedefinirSenhaTela({super.key, this.email = '', this.daSessao = false});

  /// Na entrada, o que já tinha sido digitado; pela sessão, o e-mail da conta.
  final String email;

  /// Aberta pela sessão: o e-mail fica travado no da conta.
  final bool daSessao;

  @override
  ConsumerState<RedefinirSenhaTela> createState() => _RedefinirSenhaTelaState();
}

class _RedefinirSenhaTelaState extends ConsumerState<RedefinirSenhaTela> with ExecucaoAuth {
  late final _email = TextEditingController(text: widget.email);
  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  var _codigoEnviado = false;
  String? _erroEmail;

  @override
  void initState() {
    super.initState();
    _codigo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _senha.dispose();
    super.dispose();
  }

  String get _emailDigitado => _email.text.trim().toLowerCase();

  // A senha nova é conferida antes do código porque a conferência do código cria a sessão.
  bool get _podeSalvar =>
      _codigo.text.length == CampoCodigo.tamanho && _senha.text.length >= tamanhoMinimoSenha;

  void _pedir() async {
    if (!_emailDigitado.contains('@')) {
      setState(() => _erroEmail = 'Confira o e-mail digitado.');
      return;
    }
    if (await executar((repositorio) => repositorio.pedirRedefinicao(_emailDigitado)) && mounted) {
      setState(() => _codigoEnviado = true);
    }
  }

  // Sem sessão anterior, a raiz já trocou a entrada pelo início por baixo desta tela;
  // com sessão, o início está logo abaixo. Nos dois casos, volta-se à raiz.
  void _salvar() async {
    if (!_podeSalvar) return;
    if (!await executar((repositorio) => repositorio.redefinirSenha(_emailDigitado, _codigo.text, _senha.text)) ||
        !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha trocada. Os outros aparelhos foram desconectados.')),
    );
    Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopoInterno(titulo: 'Redefinir senha', habilitado: !ocupado),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver: SliverToBoxAdapter(child: _codigoEnviado ? _etapaCodigo() : _etapaEmail()),
            ),
            // O botão fica no pé da tela quando sobra espaço e segue o conteúdo quando não sobra.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (erro != null) ...[
                      MensagemErro(erro!),
                      const SizedBox(height: 16),
                    ],
                    if (_codigoEnviado)
                      BotaoPrimario(
                        texto: 'Salvar nova senha',
                        ocupado: ocupado,
                        aoTocar: _podeSalvar ? _salvar : null,
                      )
                    else
                      BotaoPrimario(texto: 'Enviar código', ocupado: ocupado, aoTocar: _pedir),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _estiloTexto => Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 18);

  Widget _etapaEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.daSessao
              ? 'Vamos enviar um código para o e-mail da sua conta. Com ele, você escolhe a nova senha.'
              : 'Informe o e-mail da conta. Enviamos um código para você escolher a nova senha.',
          style: _estiloTexto,
        ),
        const SizedBox(height: 24),
        CampoTexto(
          rotulo: 'E-mail',
          chave: const Key('campo-email'),
          controller: _email,
          travado: widget.daSessao,
          autofocus: !widget.daSessao,
          habilitado: !ocupado,
          teclado: TextInputType.emailAddress,
          preenchimento: const [AutofillHints.email],
          acao: TextInputAction.done,
          erro: _erroEmail,
          aoMudar: (_) => setState(() => _erroEmail = null),
          aoEnviar: (_) => _pedir(),
        ),
      ],
    );
  }

  Widget _etapaCodigo() {
    const negrito = TextStyle(fontWeight: FontWeight.w700);
    final email = TextSpan(text: _emailDigitado, style: negrito);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Para e-mail sem conta o serviço responde igual, então só a sessão permite afirmar o envio.
        Text.rich(
          TextSpan(
            children: widget.daSessao
                ? [
                    const TextSpan(text: 'Digite o código enviado para '),
                    email,
                    const TextSpan(text: ' e escolha a nova senha.'),
                  ]
                : [
                    const TextSpan(text: 'Se houver conta com '),
                    email,
                    const TextSpan(text: ', enviamos um código. Digite-o e escolha a nova senha.'),
                  ],
          ),
          style: _estiloTexto,
        ),
        const SizedBox(height: 24),
        CampoCodigo(controller: _codigo, habilitado: !ocupado),
        const SizedBox(height: 16),
        Center(
          child: ReenvioCodigo(
            ocupado: ocupado,
            aoReenviar: () => executar((repositorio) async {
              _codigo.clear();
              await repositorio.pedirRedefinicao(_emailDigitado);
            }),
          ),
        ),
        const SizedBox(height: 24),
        CampoTexto(
          rotulo: 'Nova senha',
          chave: const Key('campo-senha-nova'),
          controller: _senha,
          senha: true,
          habilitado: !ocupado,
          dica: 'Mínimo de $tamanhoMinimoSenha caracteres.',
          preenchimento: const [AutofillHints.newPassword],
          acao: TextInputAction.done,
          aoMudar: (_) => setState(() {}),
          aoEnviar: (_) => _salvar(),
        ),
        const SizedBox(height: 24),
        AvisoInline(
          icone: Symbols.devices_rounded,
          cor: VoleiCores.of(context).rateio,
          texto: 'Os outros aparelhos conectados saem da conta. Este continua.',
        ),
      ],
    );
  }
}
