import '../../l10n/app_localizations.dart';
import 'error_code.dart';

/// Texto de cada [ErrorCode], do `app_pt.arb`.
///
/// O `switch` é exaustivo: código novo sem texto não compila
/// (docs/arquitetura-app.md, seção 7).
String errorText(AppLocalizations l10n, ErrorCode code) {
  return switch (code) {
    ErrorCode.notAuthenticated => l10n.errorNotAuthenticated,
    ErrorCode.notFound => l10n.errorNotFound,
    ErrorCode.invalidInput => l10n.errorInvalidInput,
    ErrorCode.internalError => l10n.errorInternalError,
    ErrorCode.noConnection => l10n.errorNoConnection,
    ErrorCode.authInvalidCredentials => l10n.errorAuthInvalidCredentials,
    ErrorCode.authEmailNotConfirmed => l10n.errorAuthEmailNotConfirmed,
    ErrorCode.authRateLimited => l10n.errorAuthRateLimited,
    ErrorCode.authWeakPassword => l10n.errorAuthWeakPassword,
    ErrorCode.authInvalidCode => l10n.errorAuthInvalidCode,
    ErrorCode.authInvalidEmail => l10n.errorAuthInvalidEmail,
    ErrorCode.authEmailInUse => l10n.errorAuthEmailInUse,
    ErrorCode.authSamePassword => l10n.errorAuthSamePassword,
    ErrorCode.authEmailRateLimited => l10n.errorAuthEmailRateLimited,
    ErrorCode.authGoogleFailed => l10n.errorAuthGoogleFailed,
    ErrorCode.pixKeyInUse => l10n.errorPixKeyInUse,
    ErrorCode.photoTooLarge => l10n.errorPhotoTooLarge,
    ErrorCode.photoInvalidType => l10n.errorPhotoInvalidType,
    ErrorCode.notAMember => l10n.errorNotAMember,
    ErrorCode.notGroupAdmin => l10n.errorNotGroupAdmin,
    ErrorCode.inviteInvalid => l10n.errorInviteInvalid,
    ErrorCode.alreadyMember => l10n.errorAlreadyMember,
    ErrorCode.joinRequestPending => l10n.errorJoinRequestPending,
    ErrorCode.requestNotPending => l10n.errorRequestNotPending,
    ErrorCode.targetNotMember => l10n.errorTargetNotMember,
    ErrorCode.cannotRemoveSelf => l10n.errorCannotRemoveSelf,
    ErrorCode.lastAdmin => l10n.errorLastAdmin,
    ErrorCode.groupHasActiveGames => l10n.errorGroupHasActiveGames,
    ErrorCode.notGameAdmin => l10n.errorNotGameAdmin,
    ErrorCode.invalidGameDates => l10n.errorInvalidGameDates,
    ErrorCode.startInPast => l10n.errorStartInPast,
    ErrorCode.receiverNeedsPixKey => l10n.errorReceiverNeedsPixKey,
    ErrorCode.noGameAccess => l10n.errorNoGameAccess,
    ErrorCode.gameNotOpen => l10n.errorGameNotOpen,
    ErrorCode.gameFull => l10n.errorGameFull,
    ErrorCode.gameNotFull => l10n.errorGameNotFull,
    ErrorCode.gameStarted => l10n.errorGameStarted,
    ErrorCode.alreadyParticipant => l10n.errorAlreadyParticipant,
    ErrorCode.alreadyOnWaitlist => l10n.errorAlreadyOnWaitlist,
    ErrorCode.slotLimitBelowParticipants =>
      l10n.errorSlotLimitBelowParticipants,
    ErrorCode.listLocked => l10n.errorListLocked,
    ErrorCode.notOnWaitlist => l10n.errorNotOnWaitlist,
    ErrorCode.notParticipant => l10n.errorNotParticipant,
    ErrorCode.receiverLocked => l10n.errorReceiverLocked,
    ErrorCode.adminMustBeParticipant => l10n.errorAdminMustBeParticipant,
    ErrorCode.alreadyGameAdmin => l10n.errorAlreadyGameAdmin,
    ErrorCode.notGameAdminTarget => l10n.errorNotGameAdminTarget,
    ErrorCode.lastGameAdmin => l10n.errorLastGameAdmin,
    ErrorCode.memberIsReceiver => l10n.errorMemberIsReceiver,
    ErrorCode.memberIsOnlyGameAdmin => l10n.errorMemberIsOnlyGameAdmin,
    ErrorCode.gameNotEnded => l10n.errorGameNotEnded,
    ErrorCode.absentNotParticipant => l10n.errorAbsentNotParticipant,
    ErrorCode.receiverCannotBeAbsent => l10n.errorReceiverCannotBeAbsent,
    ErrorCode.notAPenalty => l10n.errorNotAPenalty,
    ErrorCode.chargeNotPending => l10n.errorChargeNotPending,
    ErrorCode.gameCancelled => l10n.errorGameCancelled,
    ErrorCode.receiverMustBeParticipant => l10n.errorReceiverMustBeParticipant,
    ErrorCode.receiverUnchanged => l10n.errorReceiverUnchanged,
    ErrorCode.receiverChangeBlocked => l10n.errorReceiverChangeBlocked,
    ErrorCode.notChargeReceiver => l10n.errorNotChargeReceiver,
    ErrorCode.chargeNotRevertible => l10n.errorChargeNotRevertible,
    ErrorCode.notChargePayer => l10n.errorNotChargePayer,
    ErrorCode.receiptNotUnderReview => l10n.errorReceiptNotUnderReview,
    ErrorCode.receiptNoteRequired => l10n.errorReceiptNoteRequired,
    ErrorCode.receiptFileNotFound => l10n.errorReceiptFileNotFound,
    ErrorCode.receiptTypeInvalid => l10n.errorReceiptTypeInvalid,
    ErrorCode.receiptTooLarge => l10n.errorReceiptTooLarge,
    // O ID repetido usa o texto do resultado (copy.md, 10.7).
    ErrorCode.duplicateTransaction => l10n.receiptDuplicate,
  };
}

/// Texto de um erro qualquer, já convertido em [AppException].
String errorTextFor(AppLocalizations l10n, Object error) => errorText(
  l10n,
  error is AppException ? error.code : ErrorCode.internalError,
);
