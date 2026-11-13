import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Próprio perfil: `profiles`, `profile_private` e o e-mail da conta. Relido ao
/// voltar de cada edição (docs/ui/telas.md, 5.7).
final ownProfileProvider = FutureProvider.autoDispose<OwnProfile>(
  (ref) => ref.watch(profileRepositoryProvider).fetchOwn(),
);

/// URL assinada da foto, por caminho no bucket.
final photoUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(profileRepositoryProvider).signedPhotoUrl(path),
);
