import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// As seis casas do código de e-mail. Um campo só, invisível, recebe o que se digita ou
/// cola, e as casas desenham o valor dele: avanço, recuo e colar os seis dígitos de uma vez
/// funcionam como num campo comum.
class CampoCodigo extends StatefulWidget {
  const CampoCodigo({
    super.key,
    required this.controller,
    this.habilitado = true,
    this.aoEnviar,
  });

  static const tamanho = 6;

  final TextEditingController controller;
  final bool habilitado;
  final VoidCallback? aoEnviar;

  @override
  State<CampoCodigo> createState() => _CampoCodigoState();
}

class _CampoCodigoState extends State<CampoCodigo> {
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_aoMudar);
    _foco.addListener(_aoMudar);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_aoMudar);
    _foco.dispose();
    super.dispose();
  }

  // O cursor fica sempre no fim, porque as casas só sabem desenhar o valor da esquerda
  // para a direita. Seleção de trecho fica, para o menu de colar funcionar.
  void _aoMudar() {
    final controller = widget.controller;
    final fim = controller.text.length;
    if (controller.selection.isCollapsed && controller.selection.baseOffset != fim) {
      controller.selection = TextSelection.collapsed(offset: fim);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final texto = widget.controller.text;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < CampoCodigo.tamanho; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Casa(
                    digito: i < texto.length ? texto[i] : null,
                    ativa: _foco.hasFocus && i == texto.length,
                  ),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const Key('campo-codigo'),
                controller: widget.controller,
                focusNode: _foco,
                enabled: widget.habilitado,
                autofocus: true,
                showCursor: false,
                keyboardType: TextInputType.number,
                maxLength: CampoCodigo.tamanho,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                onSubmitted: (_) => widget.aoEnviar?.call(),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Casa extends StatelessWidget {
  const _Casa({required this.digito, required this.ativa});

  final String? digito;
  final bool ativa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final digito = this.digito;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ativa ? tema.colorScheme.primary : tema.colorScheme.surfaceContainerHigh,
          width: ativa ? 2 : 1.5,
        ),
      ),
      child: digito != null
          ? Text(digito, style: tema.textTheme.displaySmall!.copyWith(fontSize: 34))
          : ativa
              ? Container(width: 2, height: 28, color: tema.colorScheme.primary)
              : null,
    );
  }
}
