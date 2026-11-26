import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../../../core/uuid.dart';
import '../domain/group_models.dart';

/// Grupos, convite, solicitações e integrantes (RF14 a RF25, RF103;
/// specs/002-grupos/contracts/repositories.md).
///
/// Lê `groups`, `group_members`, `group_join_requests` e `profiles` direto,
/// limitado pelo RLS (docs/rls-matriz.md, fatia 3). Toda escrita passa pelas
/// funções de docs/contratos-api.md, seção 3, salvo a foto do grupo, enviada
/// direto ao Storage antes de `update_group` (seção 9).
class GroupsRepository {
  GroupsRepository(this._db);

  final SupabaseClient _db;

  static const _bucket = 'avatars';

  /// Validade da URL assinada da foto.
  static const _signedUrlSeconds = 3600;

  static const _mimeTypes = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// O grupo com o número de integrantes e o de solicitações pendentes. Para
  /// quem não é admin, o RLS não devolve as solicitações, e a conta dá zero.
  static const _groupColumns =
      'id, name, photo_path, invite_code, '
      'members:group_members(count), pending:group_join_requests(count)';

  String get _uid => _db.auth.currentUser!.id;

  Future<List<GroupSummary>> fetchMyGroups() => guard(() async {
    final uid = _uid;
    final results = await Future.wait([
      _db.from('groups').select(_groupColumns).eq('pending.status', 'pending'),
      _db.from('group_members').select('group_id, role').eq('user_id', uid),
    ]);
    final roles = {
      for (final row in results[1])
        row['group_id'] as String: GroupRole.parse(row['role'] as String),
    };
    return [
      for (final row in results[0])
        if (roles[row['id']] case final role?)
          GroupSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            photoPath: row['photo_path'] as String?,
            memberCount: _count(row['members']),
            role: role,
            pendingCount: role == GroupRole.admin ? _count(row['pending']) : 0,
          ),
    ];
  });

  Future<GroupDetail> fetchGroup(String groupId) => guard(() async {
    _requireUuid(groupId);
    final results = await Future.wait([
      _db
          .from('groups')
          .select(_groupColumns)
          .eq('id', groupId)
          .eq('pending.status', 'pending')
          .maybeSingle(),
      _db
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', _uid)
          .maybeSingle(),
    ]);
    final row = results[0];
    final me = results[1];
    // Sem acesso, sem pista (contratos-api.md, seção 1).
    if (row == null || me == null) {
      throw const AppException(ErrorCode.notFound);
    }
    final role = GroupRole.parse(me['role'] as String);
    return GroupDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      photoPath: row['photo_path'] as String?,
      inviteCode: row['invite_code'] as String?,
      memberCount: _count(row['members']),
      myRole: role,
      pendingCount: role == GroupRole.admin ? _count(row['pending']) : 0,
    );
  });

  Future<List<GroupMember>> fetchMembers(String groupId) => guard(() async {
    _requireUuid(groupId);
    final rows = await _db
        .from('group_members')
        .select('user_id, role, joined_at, profiles(display_name, photo_path)')
        .eq('group_id', groupId);
    // Quem não é membro não lê nenhuma linha.
    if (rows.isEmpty) throw const AppException(ErrorCode.notFound);
    return [
      for (final row in rows)
        GroupMember(
          userId: row['user_id'] as String,
          role: GroupRole.parse(row['role'] as String),
          joinedAt: DateTime.parse(row['joined_at'] as String),
          displayName: (row['profiles'] as Map)['display_name'] as String,
          photoPath: (row['profiles'] as Map)['photo_path'] as String?,
        ),
    ];
  });

  Future<List<JoinRequest>> fetchPendingRequests(String groupId) =>
      guard(() async {
        _requireUuid(groupId);
        // Duas chaves de group_join_requests apontam para profiles: a do
        // solicitante e a de quem decidiu.
        final rows = await _db
            .from('group_join_requests')
            .select(
              'id, user_id, created_at, '
              'profiles!group_join_requests_user_id_fkey'
              '(display_name, photo_path)',
            )
            .eq('group_id', groupId)
            .eq('status', 'pending')
            .order('created_at');
        return [
          for (final row in rows)
            JoinRequest(
              id: row['id'] as String,
              userId: row['user_id'] as String,
              createdAt: DateTime.parse(row['created_at'] as String),
              displayName: (row['profiles'] as Map)['display_name'] as String,
              photoPath: (row['profiles'] as Map)['photo_path'] as String?,
            ),
        ];
      });

  /// URL assinada no bucket privado `avatars`, para a foto do grupo e a das
  /// pessoas (docs/rls-matriz.md, fatia 3).
  Future<String> avatarUrl(String photoPath) => guard(
    () =>
        _db.storage.from(_bucket).createSignedUrl(photoPath, _signedUrlSeconds),
  );

  Future<InvitePreview> previewInvite(String code) => guard(() async {
    final response = await _db.functions.invoke(
      'preview-invite',
      body: {'code': code, 'kind': 'group'},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return InvitePreview.fromJson(data);
  });

  /// Devolve o `group_id`.
  Future<String> createGroup(String name) => guard(() async {
    final result = await _db.rpc('create_group', params: {'p_name': name});
    return (result as Map)['group_id'] as String;
  });

  /// Envia para `groups/{groupId}/{uuid}.{ext}`, sempre com nome novo e sem
  /// sobrescrever (`upsert: false`). Devolve o caminho.
  Future<String> uploadGroupPhoto({
    required String groupId,
    required Uint8List bytes,
    required String extension,
  }) => guard(() async {
    final path = 'groups/$groupId/${uuidV4()}.$extension';
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

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String? photoPath,
  }) => guard(() async {
    await _db.rpc(
      'update_group',
      params: {
        'p_group_id': groupId,
        'p_name': name,
        'p_photo_path': photoPath,
      },
    );
  });

  Future<void> deleteGroupPhoto(String photoPath) => guard(() async {
    await _db.storage.from(_bucket).remove([photoPath]);
  });

  /// Devolve o código novo.
  Future<String> regenerateInvite(String groupId) => guard(() async {
    final result = await _db.rpc(
      'regenerate_group_invite',
      params: {'p_group_id': groupId},
    );
    return (result as Map)['invite_code'] as String;
  });

  Future<void> invalidateInvite(String groupId) => guard(() async {
    await _db.rpc('invalidate_group_invite', params: {'p_group_id': groupId});
  });

  Future<void> requestJoin(String code) => guard(() async {
    await _db.rpc('request_group_join', params: {'p_invite_code': code});
  });

  Future<void> decideRequest({
    required String requestId,
    required bool approve,
  }) => guard(() async {
    await _db.rpc(
      'decide_join_request',
      params: {'p_request_id': requestId, 'p_approve': approve},
    );
  });

  Future<void> setRole({
    required String groupId,
    required String userId,
    required GroupRole role,
  }) => guard(() async {
    await _db.rpc(
      'set_group_role',
      params: {
        'p_group_id': groupId,
        'p_user_id': userId,
        'p_role': role.value,
      },
    );
  });

  /// Quantos jogos a pessoa deixou (`games_left`, RN14).
  Future<int> leaveGroup(String groupId) => guard(() async {
    final result = await _db.rpc(
      'leave_group',
      params: {'p_group_id': groupId},
    );
    return _gamesLeft(result);
  });

  /// Quantos jogos a pessoa removida deixou (`games_left`, RN14).
  Future<int> removeMember({required String groupId, required String userId}) =>
      guard(() async {
        final result = await _db.rpc(
          'remove_group_member',
          params: {'p_group_id': groupId, 'p_user_id': userId},
        );
        return _gamesLeft(result);
      });

  static int _gamesLeft(Object? result) =>
      ((result as Map?)?['games_left'] as List?)?.length ?? 0;

  Future<void> archiveGroup(String groupId) => guard(() async {
    await _db.rpc('archive_group', params: {'p_group_id': groupId});
  });

  /// `[{count: 3}]`, a contagem que o PostgREST devolve para a tabela
  /// embutida.
  static int _count(Object? embedded) {
    if (embedded is List && embedded.isNotEmpty) {
      return (embedded.first as Map)['count'] as int;
    }
    return 0;
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

/// O parâmetro da rota vem de fora: um ID que não é UUID é "não encontrado",
/// e não o erro de conversão do Postgres.
void _requireUuid(String id) {
  if (!_uuid.hasMatch(id)) throw const AppException(ErrorCode.notFound);
}

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.watch(supabaseProvider)),
);
