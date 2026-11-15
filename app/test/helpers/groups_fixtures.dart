import 'dart:typed_data';

import 'package:voleiin/core/photo_picker.dart';
import 'package:voleiin/features/groups/domain/group_models.dart';

import 'harness.dart';

// Grupos e pessoas dos cenários de docs/testes-referencia.md, seção 11.6, com
// os IDs do seed (docs/setup.md, seção 8).

const quintaId = '00000000-0000-0000-0000-000000000101';
const areiaId = '00000000-0000-0000-0000-000000000103';
const quintaName = 'Vôlei de Quinta';
const quintaCode = 'VoleiQuinta1';

/// O Vôlei de Quinta visto pelo detalhe. Por padrão, com a Ana admin, 3
/// integrantes, 2 solicitações pendentes e o código ativo.
GroupDetail quinta({
  GroupRole myRole = GroupRole.admin,
  String? inviteCode = quintaCode,
  int memberCount = 3,
  int pendingCount = 2,
  String? photoPath,
}) => GroupDetail(
  id: quintaId,
  name: quintaName,
  photoPath: photoPath,
  inviteCode: inviteCode,
  memberCount: memberCount,
  myRole: myRole,
  pendingCount: pendingCount,
);

GroupMember member(
  String userId,
  String displayName, {
  GroupRole role = GroupRole.member,
  int day = 2,
}) => GroupMember(
  userId: userId,
  role: role,
  // 12:00 em Fortaleza, longe da virada do dia.
  joinedAt: DateTime.utc(2026, 11, day, 15),
  displayName: displayName,
);

/// Ana admin, Bruno e Carla membros, fora de ordem, como o servidor pode
/// devolver.
List<GroupMember> quintaMembers({
  GroupRole anaRole = GroupRole.admin,
  GroupRole brunoRole = GroupRole.member,
  GroupRole carlaRole = GroupRole.member,
}) => [
  member(carlaId, 'Carla', role: carlaRole, day: 9),
  member(anaId, 'Ana', role: anaRole),
  member(brunoId, 'Bruno', role: brunoRole, day: 5),
];

JoinRequest joinRequest(
  String id,
  String userId,
  String displayName,
  DateTime createdAt,
) => JoinRequest(
  id: id,
  userId: userId,
  createdAt: createdAt,
  displayName: displayName,
);

InvitePreview preview({
  bool isMember = false,
  bool hasPendingRequest = false,
}) => InvitePreview(
  groupId: quintaId,
  name: quintaName,
  isMember: isMember,
  hasPendingRequest: hasPendingRequest,
);

final pickedPhoto = PickedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]),
  extension: 'jpg',
);
