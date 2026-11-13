import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/format/image_type.dart';
import '../../../core/format/uuid.dart';
import '../../../core/supabase.dart';
import '../domain/pix_key_type.dart';
import '../domain/profile.dart';
import 'auth_repository.dart';

/// Leitura e escrita do próprio perfil (contratos-api.md, seção 9; escritas
/// diretas permitidas pela rls-matriz.md, Fatia 2).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'avatars';

  String get _uid => _client.auth.currentUser!.id;

  Future<OwnProfile> fetchOwn() => guard(() async {
    final user = _client.auth.currentUser!;
    final profile = await _client
        .from('profiles')
        .select('id, name, nickname, display_name, photo_path')
        .eq('id', user.id)
        .single();
    final private = await _client
        .from('profile_private')
        .select('user_id, phone, phone_visible, pix_key_type, pix_key')
        .eq('user_id', user.id)
        .single();
    return OwnProfile(
      profile: Profile.fromJson(profile),
      private: ProfilePrivate.fromJson(private),
      email: user.email ?? '',
      hasEmailPassword: AuthRepository.hasEmailPasswordFor(user),
    );
  });

  /// Envia a foto com nome sempre novo e devolve o caminho no bucket
  /// (`profiles/{uid}/{uuid}.{ext}`). Tipo e tamanho são conferidos pelo bucket
  /// (RN106): acima de 2 MB vira `photoTooLarge`, tipo errado `photoInvalidType`.
  Future<String> uploadPhoto(Uint8List bytes, ImageType type) =>
      guard(() async {
        final path = 'profiles/$_uid/${randomUuidV4()}.${type.extension}';
        await _client.storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: type.mimeType),
            );
        return path;
      });

  /// RF08, RF09, RF12. Apelido vazio vira nulo, e o `display_name` volta ao
  /// nome (RN100).
  Future<void> updateProfile({
    required String name,
    required String? nickname,
    required String? photoPath,
  }) => guard(() async {
    await _client
        .from('profiles')
        .update({'name': name, 'nickname': nickname, 'photo_path': photoPath})
        .eq('id', _uid);
  });

  /// RF10: telefone em E.164 e visibilidade (RN101).
  Future<void> updatePrivate({
    required String? phone,
    required bool phoneVisible,
  }) => guard(() async {
    await _client
        .from('profile_private')
        .update({'phone': phone, 'phone_visible': phoneVisible})
        .eq('user_id', _uid);
  });

  /// RF11. Trocar é sempre permitido (RN105).
  Future<void> savePixKey(PixKeyType type, String key) => guard(() async {
    await _client
        .from('profile_private')
        .update({'pix_key_type': type.name, 'pix_key': key})
        .eq('user_id', _uid);
  });

  /// RF12. A trigger da RN105 recusa com `PIX_KEY_IN_USE` (`pixKeyInUse`).
  Future<void> removePixKey() => guard(() async {
    await _client
        .from('profile_private')
        .update({'pix_key_type': null, 'pix_key': null})
        .eq('user_id', _uid);
  });

  /// Apaga a foto substituída ou removida. Falha aqui não desfaz o perfil
  /// salvo: o arquivo fica para a limpeza da fatia 6 (docs/ui/telas.md, 5.8).
  Future<void> deletePhoto(String path) => guard(() async {
    await _client.storage.from(_bucket).remove([path]);
  });

  /// URL assinada da própria foto, válida por 1 hora.
  Future<String> signedPhotoUrl(String path) =>
      guard(() => _client.storage.from(_bucket).createSignedUrl(path, 3600));
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);
