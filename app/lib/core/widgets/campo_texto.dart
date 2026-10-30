import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Campo do design system: rótulo acima e fora do campo, dica opcional abaixo e erro com
/// ícone, nunca só pela cor. Com [senha], o olho alterna entre mostrar e esconder.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controller,
    this.chave,
    this.dica,
    this.erro,
    this.senha = false,
    this.travado = false,
    this.habilitado = true,
    this.autofocus = false,
    this.teclado,
    this.capitalizacao = TextCapitalization.none,
    this.preenchimento,
    this.acao,
    this.aoMudar,
    this.aoEnviar,
    this.tamanhoMaximo,
  });

  final String rotulo;
  final TextEditingController controller;

  /// Key do TextField de dentro, para os testes acharem o campo.
  final Key? chave;
  final String? dica;
  final String? erro;
  final bool senha;

  /// Mostra o valor sem deixar editar, como o e-mail da conta na troca de senha.
  final bool travado;
  final bool habilitado;
  final bool autofocus;
  final TextInputType? teclado;
  final TextCapitalization capitalizacao;
  final Iterable<String>? preenchimento;
  final TextInputAction? acao;
  final ValueChanged<String>? aoMudar;
  final ValueChanged<String>? aoEnviar;

  /// Para o teclado no limite, sem contador nem mensagem.
  final int? tamanhoMaximo;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  var _oculto = true;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final erro = widget.erro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.rotulo,
          style: tema.textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: widget.chave,
          controller: widget.controller,
          enabled: widget.habilitado,
          readOnly: widget.travado,
          autofocus: widget.autofocus,
          obscureText: widget.senha && _oculto,
          enableSuggestions: !widget.senha,
          autocorrect: !widget.senha && widget.teclado != TextInputType.emailAddress,
          keyboardType: widget.teclado,
          inputFormatters: [
            if (widget.tamanhoMaximo != null) LengthLimitingTextInputFormatter(widget.tamanhoMaximo),
          ],
          textCapitalization: widget.capitalizacao,
          autofillHints: widget.preenchimento,
          textInputAction: widget.acao,
          style: tema.textTheme.bodyLarge,
          onChanged: widget.aoMudar,
          onSubmitted: widget.aoEnviar,
          // A decoração só pinta a borda de erro: a dica e a mensagem ficam abaixo, fora do
          // campo, para alinharem com o rótulo e não com o texto de dentro.
          decoration: InputDecoration(
            error: erro == null ? null : const SizedBox.shrink(),
            suffixIcon: widget.senha
                ? IconButton(
                    tooltip: _oculto ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(_oculto ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                    onPressed: () => setState(() => _oculto = !_oculto),
                  )
                : null,
          ),
        ),
        if (erro != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Symbols.error_rounded, size: 16, color: tema.colorScheme.error),
              const SizedBox(width: 4),
              Flexible(child: Text(erro, style: tema.inputDecorationTheme.errorStyle)),
            ],
          ),
        ] else if (widget.dica != null) ...[
          const SizedBox(height: 8),
          Text(widget.dica!, style: tema.inputDecorationTheme.helperStyle),
        ],
      ],
    );
  }
}
