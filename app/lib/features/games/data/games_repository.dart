import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide ErrorCode;

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/supabase.dart';
import '../../auth/domain/pix_key.dart';
import '../domain/charge_models.dart';
import '../domain/game_models.dart';

/// Jogo, lista e espera da etapa A da fatia 4 (RF26 a RF32, RF36 a RF38,
/// RF44 a RF47, RF49, RF51 a RF53, RF55;
/// specs/003-jogo-etapa-a/contracts/repositories.md).
///
/// Lê `games`, `game_admins`, `game_participants` e `game_waitlist` direto,
/// limitado pelo RLS (docs/rls-matriz.md, fatia 4). O nome do grupo vem de
/// `get_game_groups`, e a chave Pix do recebedor, de `get_profile_contact`.
/// Toda escrita passa pelas funções de docs/contratos-api.md, seção 4.
class GamesRepository {
  GamesRepository(this._db);

  final SupabaseClient _db;

  static const _bucket = 'avatars';
  static const _signedUrlSeconds = 3600;

  /// O jogo para o card, com as passagens e a espera, das quais saem as vagas
  /// ocupadas e a situação da pessoa.
  static const _summaryColumns =
      'id, group_id, location_name, starts_at, ends_at, status, slot_limit, '
      'game_participants(user_id, status), '
      'game_waitlist(user_id, joined_at, left_at)';

  String get _uid => _db.auth.currentUser!.id;

  Future<List<GameSummary>> fetchMyGames() => guard(() async {
    final rows = await _db.from('games').select(_summaryColumns);
    return _summaries(rows);
  });

  Future<List<GameSummary>> fetchGroupGames(String groupId) => guard(() async {
    _requireUuid(groupId);
    final rows = await _db
        .from('games')
        .select(_summaryColumns)
        .eq('group_id', groupId)
        .inFilter('status', [
          GameStatus.open.value,
          GameStatus.confirmed.value,
        ]);
    return _summaries(rows);
  });

  Future<GameDetail> fetchGame(String gameId) => guard(() async {
    _requireUuid(gameId);
    final uid = _uid;
    final game = await _db
        .from('games')
        .select(
          'id, group_id, location_name, maps_url, cancellation_deadline, '
          'starts_at, ends_at, total_cents, slot_limit, status, receiver_id, '
          'share_cents, '
          'receiver:profiles!games_receiver_id_fkey(display_name, photo_path)',
        )
        .eq('id', gameId)
        .maybeSingle();
    // Sem acesso, sem pista (contratos-api.md, seção 1).
    if (game == null) throw const AppException(ErrorCode.notFound);

    final groupId = game['group_id'] as String?;
    final receiverId = game['receiver_id'] as String;
    final status = GameStatus.parse(game['status'] as String);
    // O próprio valor, no card do Rateio do jogo concluído (telas.md, 8.1).
    final myCharges = status == GameStatus.completed
        ? await _db
              .from('charges')
              .select(_chargeColumns)
              .eq('game_id', gameId)
              .eq('payer_id', uid)
        : const <Map<String, dynamic>>[];
    final results = await Future.wait<Object?>([
      _db
          .from('game_participants')
          .select(
            'user_id, status, joined_at, absent, '
            'profiles(display_name, photo_path)',
          )
          .eq('game_id', gameId)
          .inFilter('status', [
            ParticipantStatus.active.value,
            ParticipantStatus.leftAfterStart.value,
          ]),
      _db
          .from('game_waitlist')
          .select('user_id, joined_at, profiles(display_name, photo_path)')
          .eq('game_id', gameId)
          .isFilter('left_at', null),
      _db.from('game_admins').select('user_id').eq('game_id', gameId),
      _groupNames([gameId]),
      _db.rpc('get_profile_contact', params: {'p_user_id': receiverId}),
      if (groupId != null)
        _db
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId)
            .eq('user_id', uid)
            .maybeSingle(),
    ]);

    final receiver = game['receiver'] as Map?;
    final contact = Map<String, dynamic>.from(results[4] as Map);
    final pixType = contact['pix_key_type'] as String?;
    return GameDetail(
      id: game['id'] as String,
      groupId: groupId,
      groupName: (results[3] as Map<String, String>)[gameId],
      locationName: game['location_name'] as String,
      mapsUrl: game['maps_url'] as String?,
      cancellationDeadline: _instant(game['cancellation_deadline']),
      startsAt: _instant(game['starts_at']),
      endsAt: _instant(game['ends_at']),
      totalCents: game['total_cents'] as int,
      slotLimit: game['slot_limit'] as int,
      status: status,
      receiverId: receiverId,
      receiverName: receiver?['display_name'] as String? ?? '',
      receiverPhotoPath: receiver?['photo_path'] as String?,
      receiverPixKeyType: pixType == null
          ? null
          : PixKeyType.values.firstWhere((type) => type.value == pixType),
      receiverPixKey: contact['pix_key'] as String?,
      participants: [
        for (final row in results[0] as List)
          GameParticipant(
            userId: row['user_id'] as String,
            displayName: _displayName(row),
            photoPath: _photoPath(row),
            status: ParticipantStatus.parse(row['status'] as String),
            joinedAt: _instant(row['joined_at']),
            absent: row['absent'] as bool? ?? false,
          ),
      ],
      waitlist: [
        for (final row in results[1] as List)
          WaitlistEntry(
            userId: row['user_id'] as String,
            displayName: _displayName(row),
            photoPath: _photoPath(row),
            joinedAt: _instant(row['joined_at']),
          ),
      ],
      adminIds: [
        for (final row in results[2] as List) row['user_id'] as String,
      ],
      isGroupMember: results.length > 5 && results[5] != null,
      viewerId: uid,
      shareCents: game['share_cents'] as int?,
      myCharge: _myCharge([for (final row in myCharges) _charge(row)]),
    );
  });

  /// Assina `games` (filtro `id`), `game_participants` e `game_waitlist`
  /// (filtro `game_id`). O Realtime é só um sinal para reler
  /// (docs/arquitetura-app.md, seção 6). Devolve a função que cancela.
  void Function() watchGame(String gameId, void Function() onChange) {
    void callback(PostgresChangePayload _) => onChange();
    PostgresChangeFilter filter(String column) => PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: column,
      value: gameId,
    );
    final channel = _db
        .channel('game:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'games',
          filter: filter('id'),
          callback: callback,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_participants',
          filter: filter('game_id'),
          callback: callback,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_waitlist',
          filter: filter('game_id'),
          callback: callback,
        )
        .subscribe();
    return () => _db.removeChannel(channel);
  }

  /// URL assinada no bucket privado `avatars` (docs/rls-matriz.md, fatia 3:
  /// estar no mesmo jogo é contexto).
  Future<String> avatarUrl(String photoPath) => guard(
    () =>
        _db.storage.from(_bucket).createSignedUrl(photoPath, _signedUrlSeconds),
  );

  /// Os grupos de que a pessoa é membro: o RLS de `groups` devolve só eles
  /// (docs/rls-matriz.md, fatia 3).
  Future<List<GameGroupOption>> fetchMyGroupOptions() => guard(() async {
    final rows = await _db.from('groups').select('id, name');
    return [
      for (final row in rows)
        GameGroupOption(id: row['id'] as String, name: row['name'] as String),
    ];
  });

  /// Se a própria pessoa tem chave Pix (RN22).
  Future<bool> hasPixKey() => guard(() async {
    final row = await _db
        .from('profile_private')
        .select('pix_key')
        .eq('user_id', _uid)
        .maybeSingle();
    return row?['pix_key'] != null;
  });

  /// Devolve o `game_id`.
  Future<String> createGame({
    required String? groupId,
    required GameInput input,
  }) => guard(() async {
    final result = await _db.rpc(
      'create_game',
      params: {
        'p_group_id': groupId,
        ..._inputParams(input),
        'p_slot_limit': input.slotLimit,
      },
    );
    return (result as Map)['game_id'] as String;
  });

  Future<void> updateGame({required String gameId, required GameInput input}) =>
      guard(() async {
        await _db.rpc(
          'update_game',
          params: {'p_game_id': gameId, ..._inputParams(input)},
        );
      });

  Future<void> setSlotLimit({required String gameId, required int slotLimit}) =>
      guard(() async {
        await _db.rpc(
          'set_slot_limit',
          params: {'p_game_id': gameId, 'p_slot_limit': slotLimit},
        );
      });

  /// Sem o código de convite: ele passa a valer na fatia 8 (research R3).
  Future<void> joinGame(String gameId) => guard(() async {
    await _db.rpc('join_game', params: {'p_game_id': gameId});
  });

  Future<void> joinWaitlist(String gameId) => guard(() async {
    await _db.rpc('join_waitlist', params: {'p_game_id': gameId});
  });

  /// Os cards dos jogos de `detail.game_ids` (sheet de bloqueio, telas.md,
  /// 7.8), na ordem pedida.
  Future<List<GameSummary>> fetchGameSummaries(List<String> gameIds) => guard(
    () async {
      if (gameIds.isEmpty) return const <GameSummary>[];
      final rows = await _db
          .from('games')
          .select(_summaryColumns)
          .inFilter('id', gameIds);
      final summaries = await _summaries(rows);
      return [for (final id in gameIds) ...summaries.where((s) => s.id == id)];
    },
  );

  /// Os admins do jogo com o nome (telas.md, 7.5).
  Future<List<GameAdmin>> fetchGameAdmins(String gameId) => guard(() async {
    _requireUuid(gameId);
    final rows = await _db
        .from('game_admins')
        .select(
          'user_id, profiles!game_admins_user_id_fkey(display_name, photo_path)',
        )
        .eq('game_id', gameId);
    return [
      for (final row in rows)
        GameAdmin(
          userId: row['user_id'] as String,
          displayName: _displayName(row),
          photoPath: _photoPath(row),
        ),
    ];
  });

  Future<void> cancelGame(String gameId) => guard(() async {
    await _db.rpc('cancel_game', params: {'p_game_id': gameId});
  });

  Future<void> addGameAdmin({required String gameId, required String userId}) =>
      guard(() async {
        await _db.rpc(
          'add_game_admin',
          params: {'p_game_id': gameId, 'p_user_id': userId},
        );
      });

  Future<void> removeGameAdmin({
    required String gameId,
    required String userId,
  }) => guard(() async {
    await _db.rpc(
      'remove_game_admin',
      params: {'p_game_id': gameId, 'p_user_id': userId},
    );
  });

  Future<void> leaveWaitlist(String gameId) => guard(() async {
    await _db.rpc('leave_waitlist', params: {'p_game_id': gameId});
  });

  Future<LeaveOutcome> leaveGame(String gameId) => guard(() async {
    final result = await _db.rpc('leave_game', params: {'p_game_id': gameId});
    return LeaveOutcome.fromValue(
      (result as Map<String, dynamic>)['outcome'] as String,
    );
  });

  Future<void> removeParticipant({
    required String gameId,
    required String userId,
  }) => guard(() async {
    await _db.rpc(
      'remove_participant',
      params: {'p_game_id': gameId, 'p_user_id': userId},
    );
  });

  /// `preview_complete_game`: os números da conclusão, sem gravar
  /// (docs/contratos-api.md, seção 5).
  Future<CompletionPreview> previewCompleteGame({
    required String gameId,
    required int? totalCents,
    required List<String> absentUserIds,
  }) => guard(() async {
    final result = await _db.rpc(
      'preview_complete_game',
      params: _completionParams(gameId, totalCents, absentUserIds),
    );
    return CompletionPreview.fromJson(Map<String, dynamic>.from(result as Map));
  });

  /// `complete_game`, com os mesmos parâmetros do último *preview*.
  Future<CompletionPreview> completeGame({
    required String gameId,
    required int? totalCents,
    required List<String> absentUserIds,
  }) => guard(() async {
    final result = await _db.rpc(
      'complete_game',
      params: _completionParams(gameId, totalCents, absentUserIds),
    );
    return CompletionPreview.fromJson(Map<String, dynamic>.from(result as Map));
  });

  /// O Rateio do jogo concluído (docs/ui/telas.md, 8.3): o jogo, os valores
  /// que o RLS devolve (rls-matriz.md, fatia 5) e todas as passagens, para os
  /// motivos de quem não tem valor. Outro status é "não encontrado".
  Future<GameSplit> fetchSplit(String gameId) async {
    final game = await fetchGame(gameId);
    if (game.status != GameStatus.completed) {
      throw const AppException(ErrorCode.notFound);
    }
    return guard(() async {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _db.from('charges').select(_chargeColumns).eq('game_id', gameId),
        _db
            .from('game_participants')
            .select(
              'user_id, status, joined_at, late_cancellation, '
              'late_cancellation_exempt, absent, '
              'profiles(display_name, photo_path)',
            )
            .eq('game_id', gameId),
      ]);
      return GameSplit(
        game: game,
        charges: [for (final row in results[0]) _charge(row)],
        passages: [
          for (final row in results[1])
            GamePassage(
              userId: row['user_id'] as String,
              displayName: _displayName(row),
              photoPath: _photoPath(row),
              status: ParticipantStatus.parse(row['status'] as String),
              joinedAt: _instant(row['joined_at']),
              lateCancellation: row['late_cancellation'] as bool? ?? false,
              lateCancellationExempt:
                  row['late_cancellation_exempt'] as bool? ?? false,
              absent: row['absent'] as bool? ?? false,
            ),
        ],
      );
    });
  }

  static const _chargeColumns =
      'id, payer_id, receiver_id, kind, amount_cents, status, waive_reason, '
      'payer:profiles!charges_payer_id_fkey(display_name, photo_path), '
      'receiver:profiles!charges_receiver_id_fkey(display_name)';

  static GameCharge _charge(Map<String, dynamic> row) {
    final payer = row['payer'] as Map?;
    final receiver = row['receiver'] as Map?;
    final reason = row['waive_reason'] as String?;
    return GameCharge(
      id: row['id'] as String,
      payerId: row['payer_id'] as String,
      payerName: payer?['display_name'] as String? ?? '',
      payerPhotoPath: payer?['photo_path'] as String?,
      receiverId: row['receiver_id'] as String,
      receiverName: receiver?['display_name'] as String? ?? '',
      kind: ChargeKind.parse(row['kind'] as String),
      amountCents: row['amount_cents'] as int,
      status: ChargeStatus.parse(row['status'] as String),
      waiveReason: reason == null ? null : ChargeWaiveReason.parse(reason),
    );
  }

  /// O valor da pessoa: o que não é Isento, se houver.
  static GameCharge? _myCharge(List<GameCharge> charges) {
    if (charges.isEmpty) return null;
    return charges.firstWhere(
      (charge) => charge.status != ChargeStatus.waived,
      orElse: () => charges.first,
    );
  }

  static Map<String, Object?> _completionParams(
    String gameId,
    int? totalCents,
    List<String> absentUserIds,
  ) => {
    'p_game_id': gameId,
    'p_total_cents': totalCents,
    'p_absent_user_ids': absentUserIds,
  };

  static Map<String, Object?> _inputParams(GameInput input) => {
    'p_location_name': input.locationName,
    'p_maps_url': input.mapsUrl,
    'p_cancellation_deadline': input.cancellationDeadline
        .toUtc()
        .toIso8601String(),
    'p_starts_at': input.startsAt.toUtc().toIso8601String(),
    'p_ends_at': input.endsAt.toUtc().toIso8601String(),
    'p_total_cents': input.totalCents,
  };

  Future<List<GameSummary>> _summaries(List<Map<String, dynamic>> rows) async {
    final uid = _uid;
    final names = await _groupNames([
      for (final row in rows) row['id'] as String,
    ]);
    return [for (final row in rows) _summary(row, uid, names[row['id']])];
  }

  static GameSummary _summary(
    Map<String, dynamic> row,
    String uid,
    String? groupName,
  ) {
    final passages = [
      for (final passage in row['game_participants'] as List)
        (
          userId: passage['user_id'] as String,
          status: ParticipantStatus.parse(passage['status'] as String),
        ),
    ];
    final waitlist = [
      for (final line in row['game_waitlist'] as List)
        if (line['left_at'] == null)
          (
            userId: line['user_id'] as String,
            joinedAt: _instant(line['joined_at']),
          ),
    ]..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    final position = waitlist.indexWhere((line) => line.userId == uid);
    ParticipantStatus? myStatus;
    for (final passage in passages) {
      if (passage.userId == uid && passage.status.takesSlot) {
        myStatus = passage.status;
      }
    }
    return GameSummary(
      id: row['id'] as String,
      groupName: groupName,
      locationName: row['location_name'] as String,
      startsAt: _instant(row['starts_at']),
      endsAt: _instant(row['ends_at']),
      status: GameStatus.parse(row['status'] as String),
      slotLimit: row['slot_limit'] as int,
      occupiedSlots: passages.where((p) => p.status.takesSlot).length,
      myStatus: myStatus,
      myWaitlistPosition: position < 0 ? null : position + 1,
    );
  }

  /// `game_id` → nome do grupo, pelo `get_game_groups`. O avulso fica de fora.
  Future<Map<String, String>> _groupNames(List<String> gameIds) async {
    if (gameIds.isEmpty) return const {};
    final rows = await _db.rpc(
      'get_game_groups',
      params: {'p_game_ids': gameIds},
    );
    return {
      for (final row in rows as List)
        row['game_id'] as String: row['group_name'] as String,
    };
  }

  /// O perfil vem pela política de contexto (rls-matriz.md, fatia 4): estar
  /// no mesmo jogo é contexto, então ele sempre chega para quem vê o jogo.
  static String _displayName(Map row) =>
      (row['profiles'] as Map?)?['display_name'] as String? ?? '';

  static String? _photoPath(Map row) =>
      (row['profiles'] as Map?)?['photo_path'] as String?;

  static DateTime _instant(Object? value) =>
      DateTime.parse(value as String).toUtc();
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{12}$',
);

/// O parâmetro da rota vem de fora: um ID que não é UUID é "não encontrado".
void _requireUuid(String id) {
  if (!_uuid.hasMatch(id)) throw const AppException(ErrorCode.notFound);
}

final gamesRepositoryProvider = Provider<GamesRepository>(
  (ref) => GamesRepository(ref.watch(supabaseProvider)),
);
