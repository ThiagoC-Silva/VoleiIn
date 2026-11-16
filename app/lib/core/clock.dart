import 'package:flutter_riverpod/flutter_riverpod.dart';

/// O relógio do aparelho, trocável por dublê nos testes.
///
/// Só para **mostrar**: os selos de tempo, o que aparece no pé do detalhe do
/// jogo e o aviso de início no passado do formulário. Nunca libera uma ação
/// nem decide um resultado: quem decide é o servidor, com o relógio dele
/// (RN02; docs/arquitetura-app.md, seção 8).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
