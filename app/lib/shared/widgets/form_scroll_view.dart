import 'package:flutter/material.dart';

/// Corpo de formulário que rola quando o teclado abre ou a fonte cresce
/// (RNF05), com o [footer] no pé da tela quando sobra espaço.
class FormScrollView extends StatelessWidget {
  const FormScrollView({
    required this.content,
    this.footer = const [],
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
    super.key,
  });

  final List<Widget> content;
  final List<Widget> footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding.copyWith(bottom: 0),
          // Tudo montado de uma vez, e não sob demanda: um campo fora da tela
          // que não existe na árvore fica de fora do `Form.validate()`.
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: padding.copyWith(top: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: footer,
            ),
          ),
        ),
      ],
    );
  }
}
