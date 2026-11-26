/// Códigos de erro que o app conhece.
///
/// São os códigos estáveis de docs/contratos-api.md (seção 2) que o app já usa,
/// mais os de autenticação e o de falta de conexão. O enum cresce a cada fatia,
/// junto com os textos de docs/copy.md (seções 5.5, 6.8, 7.7 e 8.8).
enum ErrorCode {
  // Gerais (contratos-api.md, seção 2)
  notAuthenticated,
  notFound,
  invalidInput,
  internalError,

  // Só do app
  noConnection,

  // Supabase Auth (docs/copy.md, seção 5.5)
  authInvalidCredentials,
  authEmailNotConfirmed,
  authRateLimited,

  // Supabase Auth da fatia 2 (docs/copy.md, 6.8)
  authWeakPassword,
  authInvalidCode,
  authInvalidEmail,
  authEmailInUse,
  authSamePassword,
  authEmailRateLimited,

  // Google, só do app (docs/copy.md, 6.8)
  authGoogleFailed,

  // Banco e Storage (docs/copy.md, 6.8)
  pixKeyInUse,
  photoTooLarge,
  photoInvalidType,

  // Grupos e convites (docs/copy.md, 7.7). MEMBER_IS_RECEIVER e
  // MEMBER_IS_ONLY_GAME_ADMIN entram na fatia 4, com a RN16.
  notAMember,
  notGroupAdmin,
  inviteInvalid,
  alreadyMember,
  joinRequestPending,
  requestNotPending,
  targetNotMember,
  cannotRemoveSelf,
  lastAdmin,
  groupHasActiveGames,

  // Jogo e lista, etapa A da fatia 4 (docs/copy.md, 8.8): os códigos de
  // create_game, update_game, join_game, join_waitlist e set_slot_limit. As
  // etapas B e C acrescentam os seus.
  notGameAdmin,
  invalidGameDates,
  startInPast,
  receiverNeedsPixKey,
  noGameAccess,
  gameNotOpen,
  gameFull,
  gameNotFull,
  gameStarted,
  alreadyParticipant,
  alreadyOnWaitlist,
  slotLimitBelowParticipants,
  listLocked,
  notOnWaitlist,
  notParticipant,
  receiverLocked,
  adminMustBeParticipant,
  alreadyGameAdmin,
  notGameAdminTarget,
  lastGameAdmin,
  memberIsReceiver,
  memberIsOnlyGameAdmin,

  // Conclusão, etapa A da fatia 5 (docs/copy.md, 9.6): os códigos de
  // preview_complete_game e complete_game. As etapas B e C acrescentam os seus.
  gameNotEnded,
  absentNotParticipant,
  receiverCannotBeAbsent,

  // Isenção manual, etapa B da fatia 5: os códigos de waive_penalty.
  notAPenalty,
  chargeNotPending,

  // Troca de recebedor, etapa C da fatia 5: os códigos de change_receiver.
  gameCancelled,
  receiverMustBeParticipant,
  receiverUnchanged,
  receiverChangeBlocked,

  // Pagamento manual, etapa A da fatia 6 (docs/copy.md, 10.7): os códigos de
  // mark_charge_paid e revert_charge. As etapas B e C acrescentam os seus.
  notChargeReceiver,
  chargeNotRevertible,

  // Comprovantes, etapa B da fatia 6 (docs/copy.md, 10.7): os códigos de
  // process-receipt e review_receipt.
  notChargePayer,
  receiptNotUnderReview,
  receiptNoteRequired,
  receiptFileNotFound,
  receiptTypeInvalid,
  receiptTooLarge,
  duplicateTransaction,
}

/// Único tipo de exceção que sai da camada `data`.
class AppException implements Exception {
  const AppException(this.code, {this.gameIds = const []});

  final ErrorCode code;

  /// Os jogos de `detail.game_ids`, em `MEMBER_IS_RECEIVER` e
  /// `MEMBER_IS_ONLY_GAME_ADMIN` (RN16; E16). Vazio nos outros códigos.
  final List<String> gameIds;

  @override
  String toString() => 'AppException(${code.name})';
}
