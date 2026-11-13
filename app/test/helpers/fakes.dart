import 'dart:convert';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:voleiin/core/format/image_type.dart';
import 'package:voleiin/features/auth/data/auth_repository.dart';
import 'package:voleiin/features/auth/data/photo_picker.dart';
import 'package:voleiin/features/auth/data/profile_repository.dart';
import 'package:voleiin/features/auth/data/terms_repository.dart';
import 'package:voleiin/features/auth/domain/pix_key_type.dart';
import 'package:voleiin/features/auth/domain/profile.dart';
import 'package:voleiin/features/auth/domain/terms.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockTermsRepository extends Mock implements TermsRepository {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

const anaId = '00000000-0000-0000-0000-00000000000a';

/// PNG válido de 1 x 1, para o avatar decodificar a foto escolhida.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

OwnProfile ownProfile({
  String name = 'Ana Souza',
  String? nickname,
  String? photoPath,
  String? phone,
  bool phoneVisible = false,
  PixKeyType? pixKeyType,
  String? pixKey,
  bool hasEmailPassword = true,
}) => OwnProfile(
  profile: Profile(
    id: anaId,
    name: name,
    nickname: nickname,
    displayName: nickname ?? name,
    photoPath: photoPath,
  ),
  private: ProfilePrivate(
    userId: anaId,
    phone: phone,
    phoneVisible: phoneVisible,
    pixKeyType: pixKeyType,
    pixKey: pixKey,
  ),
  email: 'ana@voleiin.test',
  hasEmailPassword: hasEmailPassword,
);

const termsOfUse10 = TermsVersion(
  document: LegalDocument.termsOfUse,
  version: '1.0',
);
const privacy10 = TermsVersion(
  document: LegalDocument.privacyPolicy,
  version: '1.0',
);
const termsOfUse11 = TermsVersion(
  document: LegalDocument.termsOfUse,
  version: '1.1',
);

/// Registra os valores de mentira que o mocktail exige para `any()`.
void registerFakes() {
  registerFallbackValue(Uint8List(0));
  registerFallbackValue(ImageType.png);
  registerFallbackValue(PixKeyType.cpf);
  registerFallbackValue(PhotoSource.gallery);
  registerFallbackValue(<TermsVersion>[]);
}
