import 'dart:convert';
import 'dart:io';

import 'package:voleiin/core/env.dart';

/// Leitura dos e-mails do Supabase local pela API do Mailpit
/// (docs/testes-referencia.md, 10.4). No emulador, o Mailpit fica no mesmo
/// endereço do Supabase, na porta 54324 (`http://10.0.2.2:54324`).
class Mailpit {
  Mailpit() : _base = Uri.parse(Env.supabaseUrl).replace(port: 54324, path: '');

  final Uri _base;
  final _client = HttpClient();

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final request = await _client.getUrl(
      _base.replace(path: path, queryParameters: query),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('Mailpit $path: ${response.statusCode} $body');
    }
    return jsonDecode(body);
  }

  Future<List<String>> _messageIds(String to) async {
    final result = await _get('/api/v1/search', {
      'query': 'to:"$to"',
    }) as Map<String, dynamic>;
    final messages = (result['messages'] as List?) ?? const [];
    return [
      for (final m in messages) (m as Map<String, dynamic>)['ID'] as String,
    ];
  }

  /// Marca os e-mails que já existem para o endereço. Chame antes da ação que
  /// envia o código, e passe o resultado para [waitForCode].
  Future<Set<String>> snapshot(String to) async =>
      (await _messageIds(to)).toSet();

  /// Espera um e-mail novo para o endereço e devolve o código de 6 dígitos.
  Future<String> waitForCode(
    String to, {
    required Set<String> before,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final fresh = (await _messageIds(to)).where((id) => !before.contains(id));
      if (fresh.isNotEmpty) {
        final message = await _get(
          '/api/v1/message/${fresh.first}',
        ) as Map<String, dynamic>;
        final text = '${message['Subject']}\n${message['Text']}';
        final code = RegExp(r'\b\d{6}\b').firstMatch(text)?.group(0);
        if (code != null) return code;
        throw StateError('E-mail para $to sem código de 6 dígitos: $text');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw StateError('Nenhum e-mail novo para $to em ${timeout.inSeconds} s');
  }

  void close() => _client.close(force: true);
}
