import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/tema.dart';
import '../../core/widgets/botao_primario.dart';
import '../../core/widgets/campo_texto.dart';
import '../../core/widgets/mensagem_erro.dart';
import '../../dados/auth_repositorio.dart';
import 'confirmar_email_tela.dart';
import 'criar_conta_tela.dart';
import 'execucao_auth.dart';

/// A1 — Entrar (RF01, RN21): e-mail e senha, ou a conta Google. Criar conta abre a A2.
/// Ao entrar, a sessão muda e a raiz troca a tela sozinha.
class EntrarTela extends ConsumerStatefulWidget {
  const EntrarTela({super.key});

  @override
  ConsumerState<EntrarTela> createState() => _EntrarTelaState();
}

class _EntrarTelaState extends ConsumerState<EntrarTela> with ExecucaoAuth {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  String? _erroEmail;
  String? _erroSenha;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  String get _emailDigitado => _email.text.trim().toLowerCase();

  void _abrir(Widget tela) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));

  void _entrar() {
    setState(() {
      _erroEmail = _emailDigitado.contains('@') ? null : 'Confira o e-mail digitado.';
      _erroSenha = _senha.text.length >= tamanhoMinimoSenha
          ? null
          : 'A senha precisa de pelo menos $tamanhoMinimoSenha caracteres.';
      erro = null;
    });
    if (_erroEmail != null || _erroSenha != null) return;
    final email = _emailDigitado;
    executar((repositorio) async {
      final confirmado = await repositorio.entrar(email, _senha.text);
      if (!confirmado && mounted) _abrir(ConfirmarEmailTela(email: email));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Topo()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CampoTexto(
                        rotulo: 'E-mail',
                        chave: const Key('campo-email'),
                        controller: _email,
                        habilitado: !ocupado,
                        teclado: TextInputType.emailAddress,
                        preenchimento: const [AutofillHints.email],
                        acao: TextInputAction.next,
                        erro: _erroEmail,
                        aoMudar: (_) => setState(() => _erroEmail = null),
                      ),
                      const SizedBox(height: 16),
                      CampoTexto(
                        rotulo: 'Senha',
                        chave: const Key('campo-senha'),
                        controller: _senha,
                        senha: true,
                        habilitado: !ocupado,
                        preenchimento: const [AutofillHints.password],
                        acao: TextInputAction.done,
                        erro: _erroSenha,
                        aoMudar: (_) => setState(() => _erroSenha = null),
                        aoEnviar: (_) => _entrar(),
                      ),
                      const SizedBox(height: 24),
                      if (erro != null) ...[
                        MensagemErro(erro!),
                        const SizedBox(height: 16),
                      ],
                      BotaoPrimario(texto: 'Entrar', ocupado: ocupado, aoTocar: _entrar),
                      const SizedBox(height: 16),
                      const _Ou(),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: ocupado ? null : () => executar((repositorio) => repositorio.entrarComGoogle()),
                        icon: const Icon(Symbols.account_circle_rounded),
                        label: const Text('Entrar com Google'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // O rodapé desce até o fim da tela quando sobra espaço e segue o formulário
            // quando não sobra, como com o teclado aberto.
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Ainda não tem conta?',
                          style: tema.textTheme.bodyLarge!.copyWith(color: tema.colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                          onPressed: ocupado ? null : () => _abrir(CriarContaTela(email: _emailDigitado)),
                          child: const Text('Criar conta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Topo amarelo com o logo, o título e o círculo de decoração.
class _Topo extends StatelessWidget {
  const _Topo();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = VoleiCores.of(context);
    final navy = cores.sobreBloco;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: ColoredBox(
        color: cores.jogo,
        child: Stack(
          children: [
            Positioned(
              top: 48,
              right: -24,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: navy.withValues(alpha: 0.08), width: 30),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Logo(cor: navy),
                  const SizedBox(height: 20),
                  Text(
                    'Entrar no VoleiIn',
                    style: tema.textTheme.headlineLarge!.copyWith(fontSize: 36, height: 1.15, color: navy),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Use seu e-mail e senha ou a conta Google.',
                    style: tema.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w500, color: navy),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Espaço reservado do logo, tracejado, até o logo existir (passo 10).
class _Logo extends StatelessWidget {
  const _Logo({required this.cor});

  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _Tracejado(cor),
      child: SizedBox.square(
        dimension: 58,
        child: Center(
          child: Text(
            'LOGO',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: cor,
                ),
          ),
        ),
      ),
    );
  }
}

class _Tracejado extends CustomPainter {
  const _Tracejado(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final contorno = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)));
    const traco = 6.0;
    const vao = 4.0;
    for (final medida in contorno.computeMetrics()) {
      for (var inicio = 0.0; inicio < medida.length; inicio += traco + vao) {
        canvas.drawPath(medida.extractPath(inicio, inicio + traco), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_Tracejado anterior) => anterior.cor != cor;
}

class _Ou extends StatelessWidget {
  const _Ou();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ou',
            style: tema.textTheme.bodyLarge!.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
