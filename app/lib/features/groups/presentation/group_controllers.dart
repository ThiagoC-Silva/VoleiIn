import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/photo_picker.dart';
import '../../../core/submit_controller.dart';
import '../data/groups_repository.dart';
import '../domain/group_models.dart';
import 'groups_providers.dart';

/// Resultado da criação (docs/ui/telas.md, 6.2): o grupo pode existir mesmo
/// com a foto recusada.
class GroupCreation {
  const GroupCreation({this.groupId, this.photoFailed = false, this.error});

  final String? groupId;
  final bool photoFailed;

  /// Falha no `create_group`: o grupo não existe.
  final AppException? error;
}

/// Criar, editar e excluir o grupo (telas.md, 6.2 e 6.8).
class GroupFormController extends SubmitController {
  GroupsRepository get _groups => ref.read(groupsRepositoryProvider);

  /// Galeria ou câmera. Nulo se a pessoa desistiu; tipo recusado lança
  /// `AppException(photoInvalidType)`.
  Future<PickedPhoto?> pickPhoto(PhotoSource source) =>
      ref.read(photoPickerProvider).pick(source);

  /// Nesta ordem: `create_group`; com foto, o envio para
  /// `groups/{group_id}/...` e `update_group` com o caminho. A foto vem depois
  /// porque o caminho usa o `group_id` (contratos-api.md, `create_group`).
  Future<GroupCreation> create({
    required String name,
    PickedPhoto? photo,
  }) async {
    String? groupId;
    var photoFailed = false;
    final error = await submit(() async {
      final id = groupId = await _groups.createGroup(name);
      if (photo == null) return;
      try {
        final path = await _groups.uploadGroupPhoto(
          groupId: id,
          bytes: photo.bytes,
          extension: photo.extension,
        );
        await _groups.updateGroup(groupId: id, name: name, photoPath: path);
      } catch (_) {
        // O grupo já existe. Uma foto enviada sem uso fica no bucket até a
        // limpeza da fatia 6.
        photoFailed = true;
      }
    });
    if (ref.mounted) ref.invalidate(myGroupsProvider);
    return GroupCreation(
      groupId: groupId,
      photoFailed: photoFailed,
      error: error,
    );
  }

  /// Nesta ordem: a foto nova, se houver; `update_group` com o nome e o
  /// caminho (o novo, o atual ou nulo); por fim, apaga a foto antiga, se foi
  /// trocada ou removida. A falha ao apagar é ignorada: o grupo já está salvo.
  Future<AppException?> save({
    required String groupId,
    required String name,
    required String? currentPhotoPath,
    required PhotoChange photo,
  }) async {
    final error = await submit(() async {
      var photoPath = currentPhotoPath;
      if (photo case PhotoReplaced(:final photo)) {
        photoPath = await _groups.uploadGroupPhoto(
          groupId: groupId,
          bytes: photo.bytes,
          extension: photo.extension,
        );
      } else if (photo is PhotoRemoved) {
        photoPath = null;
      }
      await _groups.updateGroup(
        groupId: groupId,
        name: name,
        photoPath: photoPath,
      );
      if (currentPhotoPath != null && photo is! PhotoKept) {
        try {
          await _groups.deleteGroupPhoto(currentPhotoPath);
        } catch (_) {
          // O arquivo fica para a limpeza da fatia 6 (modelo-dados.md, 7).
        }
      }
    });
    if (ref.mounted) {
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(myGroupsProvider);
    }
    return error;
  }

  Future<AppException?> archive(String groupId) async {
    final error = await submit(() => _groups.archiveGroup(groupId));
    if (ref.mounted) ref.invalidate(myGroupsProvider);
    return error;
  }
}

final groupFormControllerProvider =
    AsyncNotifierProvider.autoDispose<GroupFormController, void>(
      GroupFormController.new,
    );

/// Entrar com código (telas.md, 6.3).
class GroupJoinController extends SubmitController {
  GroupsRepository get _groups => ref.read(groupsRepositoryProvider);

  /// A prévia, ou o erro (`inviteInvalid` vai para o campo).
  Future<(InvitePreview?, AppException?)> preview(String code) async {
    InvitePreview? result;
    final error = await submit(() async {
      result = await _groups.previewInvite(code);
    });
    return (result, error);
  }

  Future<AppException?> request(String code) async {
    final error = await submit(() => _groups.requestJoin(code));
    if (ref.mounted) ref.invalidate(myGroupsProvider);
    return error;
  }
}

final groupJoinControllerProvider =
    AsyncNotifierProvider.autoDispose<GroupJoinController, void>(
      GroupJoinController.new,
    );

/// Ações sobre um grupo existente: sair, convite, papéis, remoção e
/// solicitações (telas.md, 6.4 a 6.7). Depois de cada uma, com sucesso ou
/// erro, as leituras afetadas são relidas: um erro como `NOT_GROUP_ADMIN`,
/// `TARGET_NOT_MEMBER` ou `REQUEST_NOT_PENDING` indica que os dados mudaram.
class GroupActionsController extends SubmitController {
  GroupsRepository get _groups => ref.read(groupsRepositoryProvider);

  /// Na saída, só Meus grupos relê: o detalhe sai da tela.
  Future<AppException?> leave(String groupId) async {
    final error = await submit(() => _groups.leaveGroup(groupId));
    if (ref.mounted) {
      ref.invalidate(myGroupsProvider);
      if (error != null) ref.invalidate(groupDetailProvider(groupId));
    }
    return error;
  }

  Future<AppException?> regenerateInvite(String groupId) =>
      _run(groupId, () => _groups.regenerateInvite(groupId));

  Future<AppException?> invalidateInvite(String groupId) =>
      _run(groupId, () => _groups.invalidateInvite(groupId));

  Future<AppException?> setRole({
    required String groupId,
    required String userId,
    required GroupRole role,
  }) => _run(
    groupId,
    () => _groups.setRole(groupId: groupId, userId: userId, role: role),
    members: true,
  );

  Future<AppException?> removeMember({
    required String groupId,
    required String userId,
  }) => _run(
    groupId,
    () => _groups.removeMember(groupId: groupId, userId: userId),
    members: true,
  );

  Future<AppException?> decideRequest({
    required String groupId,
    required String requestId,
    required bool approve,
  }) => _run(
    groupId,
    () => _groups.decideRequest(requestId: requestId, approve: approve),
    requests: true,
  );

  Future<AppException?> _run(
    String groupId,
    Future<void> Function() action, {
    bool members = false,
    bool requests = false,
  }) async {
    final error = await submit(action);
    if (ref.mounted) {
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(myGroupsProvider);
      if (members) ref.invalidate(groupMembersProvider(groupId));
      if (requests) ref.invalidate(groupRequestsProvider(groupId));
    }
    return error;
  }
}

final groupActionsControllerProvider =
    AsyncNotifierProvider.autoDispose<GroupActionsController, void>(
      GroupActionsController.new,
    );
