import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../../../core/uuid.dart';
import '../domain/own_profile.dart';
import '../domain/pix_key.dart';
import '../domain/profile.dart';
import '../domain/profile_private.dart';

/// Própria linha de `profiles` e de `profile_private`, e as fotos do bucket
/// `avatars` (docs/rls-matriz.md, fatia 2). As escritas diretas são as que
/// `docs/contratos-api.md`, seção 9, permite.
class ProfileRepository {
  ProfileRepository(this._db);

  final SupabaseClient _db;

  static const _bucket = 'avatars';

  /// Validade da URL assinada da foto.
  static const _signedUrlSeconds = 3600;

  static const _mimeTypes = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  String get _uid => _db.auth.currentUser!.id;

  Future<OwnProfile> fetchOwn() => guard(() async {
    final uid = _uid;
    final results = await Future.wait([
      _db
          .from('profiles')
          .select('id, name, nickname, display_name, photo_path')
          .eq('id', uid)
          .single(),
      _db
          .from('profile_private')
          .select('phone, phone_visible, pix_key_type, pix_key')
          .eq('user_id', uid)
          .single(),
    ]);
    return OwnProfile(
      profile: Profile.fromJson(results[0]),
      private: ProfilePrivate.fromJson(results[1]),
    );
  });

  /// Perfil de outra pessoa (RF19, RN107; docs/ui/telas.md, 6.9). Quem o vê
  /// é decidido pelo RLS: contexto ou solicitação pendente num grupo que quem
  /// chama administra. Sem linha, ou com um ID que não é UUID, "não
  /// encontrado", sem dizer qual dos dois (contratos-api.md, seção 1).
  /// O telefone de outra pessoa, ou nulo: oculto, sem telefone ou sem
  /// contexto, sem dizer qual (`get_profile_contact`, RN101; telas.md, 7.9).
  Future<String?> fetchContactPhone(String userId) => guard(() async {
    if (!_uuidPattern.hasMatch(userId)) return null;
    final contact = await _db.rpc(
      'get_profile_contact',
      params: {'p_user_id': userId},
    );
    return (contact as Map?)?['phone'] as String?;
  });

  Future<Profile> fetchProfile(String userId) => guard(() async {
    if (!_uuidPattern.hasMatch(userId)) {
      throw const AppException(ErrorCode.notFound);
    }
    final row = await _db
        .from('profiles')
        .select('id, name, nickname, display_name, photo_path')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) throw const AppException(ErrorCode.notFound);
    return Profile.fromJson(row);
  });

  Future<String> avatarUrl(String photoPath) => guard(
    () =>
        _db.storage.from(_bucket).createSignedUrl(photoPath, _signedUrlSeconds),
  );

  /// Envia para `profiles/{uid}/{uuid}.{ext}`, sempre com nome novo e sem
  /// sobrescrever (`upsert: false`). Devolve o caminho.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String extension,
  }) => guard(() async {
    final path = 'profiles/$_uid/${uuidV4()}.$extension';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeTypes[extension],
            upsert: false,
          ),
        );
    return path;
  });

  Future<void> updateProfile({
    required String name,
    required String? nickname,
    required String? photoPath,
  }) => guard(() async {
    await _db
        .from('profiles')
        .update({'name': name, 'nickname': nickname, 'photo_path': photoPath})
        .eq('id', _uid);
  });

  Future<void> updateContact({
    required String? phone,
    required bool phoneVisible,
  }) => guard(() async {
    await _db
        .from('profile_private')
        .update({'phone': phone, 'phone_visible': phoneVisible})
        .eq('user_id', _uid);
  });

  Future<void> deleteAvatar(String photoPath) => guard(() async {
    await _db.storage.from(_bucket).remove([photoPath]);
  });

  /// Os dois nulos removem a chave. A *trigger* da RN105 recusa a remoção com
  /// `PIX_KEY_IN_USE`.
  Future<void> updatePixKey({
    required PixKeyType? type,
    required String? key,
  }) => guard(() async {
    await _db
        .from('profile_private')
        .update({'pix_key_type': type?.value, 'pix_key': key})
        .eq('user_id', _uid);
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);
