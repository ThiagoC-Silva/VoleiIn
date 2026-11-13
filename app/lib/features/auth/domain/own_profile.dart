import 'package:freezed_annotation/freezed_annotation.dart';

import 'profile.dart';
import 'profile_private.dart';

part 'own_profile.freezed.dart';

/// As duas linhas da própria pessoa, lidas juntas pelo perfil e pelas edições.
@freezed
abstract class OwnProfile with _$OwnProfile {
  const factory OwnProfile({
    required Profile profile,
    required ProfilePrivate private,
  }) = _OwnProfile;
}
