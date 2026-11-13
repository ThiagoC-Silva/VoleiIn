import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../domain/terms.dart';

/// Versões vigentes e aceites dos termos (RF105; docs/contratos-api.md, 9).
class TermsRepository {
  TermsRepository(this._db);

  final SupabaseClient _db;

  Future<List<TermsVersion>> currentVersions() => guard(() async {
    final rows = await _db.rpc<List<dynamic>>('current_terms_versions');
    return [
      for (final row in rows)
        TermsVersion.fromJson(row as Map<String, dynamic>),
    ];
  });

  Future<List<TermsVersion>> ownAcceptances() => guard(() async {
    final rows = await _db
        .from('terms_acceptances')
        .select('document, version')
        .eq('user_id', _db.auth.currentUser!.id);
    return [for (final row in rows) TermsVersion.fromJson(row)];
  });

  /// Uma linha por documento. O instante vem do `now()` do servidor (RN02), e
  /// o RLS recusa a versão que não é a vigente.
  Future<void> accept(List<TermsVersion> versions) => guard(() async {
    final uid = _db.auth.currentUser!.id;
    await _db.from('terms_acceptances').insert([
      for (final v in versions)
        {'user_id': uid, 'document': v.document.value, 'version': v.version},
    ]);
  });
}

final termsRepositoryProvider = Provider<TermsRepository>(
  (ref) => TermsRepository(ref.watch(supabaseProvider)),
);
