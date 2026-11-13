import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../domain/terms.dart';

/// Versões vigentes e aceites dos termos (RF105; contratos-api.md, seção 9).
class TermsRepository {
  TermsRepository(this._client);

  final SupabaseClient _client;

  Future<TermsStatus> fetchStatus() => guard(() async {
    final current = await _client.rpc<List<dynamic>>('current_terms_versions');
    final accepted = await _client
        .from('terms_acceptances')
        .select('document, version');
    return TermsStatus.compare(
      current: current
          .map((row) => TermsVersion.fromJson(row as Map<String, dynamic>))
          .toList(),
      accepted: accepted.map(TermsVersion.fromJson).toList(),
    );
  });

  /// Uma linha por documento que falta. O instante vem do servidor (RN02); a
  /// versão que deixou de ser a vigente é recusada pelo RLS.
  Future<void> accept(List<TermsVersion> missing) => guard(() async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('terms_acceptances').insert([
      for (final v in missing)
        {
          'user_id': userId,
          'document': v.document.dbValue,
          'version': v.version,
        },
    ]);
  });
}

final termsRepositoryProvider = Provider<TermsRepository>(
  (ref) => TermsRepository(ref.watch(supabaseProvider)),
);
