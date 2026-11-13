import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/own_profile.dart';

/// Perfil da própria pessoa (docs/ui/telas.md, 5.7). As edições chamam
/// `ref.invalidate` depois de gravar, e o perfil relê do servidor.
final ownProfileProvider = FutureProvider.autoDispose<OwnProfile>(
  (ref) => ref.watch(profileRepositoryProvider).fetchOwn(),
);

/// URL assinada da foto no bucket privado `avatars`.
final avatarUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, photoPath) => ref.watch(profileRepositoryProvider).avatarUrl(photoPath),
);
