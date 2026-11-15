import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/own_profile.dart';
import '../domain/profile.dart';

/// Perfil da própria pessoa (docs/ui/telas.md, 5.7). As edições chamam
/// `ref.invalidate` depois de gravar, e o perfil relê do servidor.
final ownProfileProvider = FutureProvider.autoDispose<OwnProfile>(
  (ref) => ref.watch(profileRepositoryProvider).fetchOwn(),
);

/// URL assinada da foto no bucket privado `avatars`.
final avatarUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, photoPath) => ref.watch(profileRepositoryProvider).avatarUrl(photoPath),
);

/// Perfil de outra pessoa (docs/ui/telas.md, 6.9), lido pelo RLS.
final personProvider = FutureProvider.autoDispose.family<Profile, String>(
  (ref, userId) => ref.watch(profileRepositoryProvider).fetchProfile(userId),
);
