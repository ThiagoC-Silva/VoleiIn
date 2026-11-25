import 'package:flutter_test/flutter_test.dart';
import 'package:voleiin/core/errors/error_code.dart';
import 'package:voleiin/core/errors/error_text.dart';

import '../../helpers/test_app.dart';

/// Cenário E08 de docs/testes-referencia.md, seção 9.4: cada ErrorCode tem
/// texto no app_pt.arb, e nenhum é vazio.
void main() {
  test('E08: todo ErrorCode tem texto não vazio', () {
    for (final code in ErrorCode.values) {
      expect(errorText(l10nPt, code), isNotEmpty, reason: code.name);
    }
  });

  test('os textos dos erros gerais são os do catálogo (docs/copy.md, 5.5)', () {
    expect(
      errorText(l10nPt, ErrorCode.notFound),
      'Não encontramos o que você procura.',
    );
    expect(
      errorText(l10nPt, ErrorCode.authInvalidCredentials),
      'E-mail ou senha incorretos.',
    );
  });

  test('os textos dos erros da fatia 2 são os do catálogo (docs/copy.md)', () {
    // Seção 5.5: o texto deixou de citar o link (ADR 0017).
    expect(
      errorText(l10nPt, ErrorCode.authEmailNotConfirmed),
      'Confirme o seu e-mail antes de entrar.',
    );
    // Seção 6.8.
    expect(
      errorText(l10nPt, ErrorCode.authInvalidCode),
      'Código incorreto ou vencido. Confira ou peça um novo.',
    );
    expect(
      errorText(l10nPt, ErrorCode.authGoogleFailed),
      'Não foi possível entrar com o Google. Tente de novo.',
    );
    expect(
      errorText(l10nPt, ErrorCode.pixKeyInUse),
      'Você pode trocar a chave, mas não removê-la enquanto tiver jogos em '
      'aberto ou valores a receber.',
    );
    expect(
      errorText(l10nPt, ErrorCode.photoTooLarge),
      'A foto passa de 2 MB. Escolha outra.',
    );
    expect(
      errorText(l10nPt, ErrorCode.photoInvalidType),
      'Use uma foto JPEG, PNG ou WebP.',
    );
  });
  test(
    'os textos dos erros de grupo são os do catálogo (docs/copy.md, 7.7)',
    () {
      const texts = {
        ErrorCode.notAMember: 'Você não é membro deste grupo.',
        ErrorCode.notGroupAdmin: 'Só um admin do grupo pode fazer isso.',
        ErrorCode.inviteInvalid:
            'Este código não vale. Confira ou peça um novo ao grupo.',
        ErrorCode.alreadyMember: 'Você já é membro deste grupo.',
        ErrorCode.joinRequestPending:
            'Você já pediu para entrar neste grupo. Aguarde a aprovação de um '
            'admin.',
        ErrorCode.requestNotPending: 'Esta solicitação já foi decidida.',
        ErrorCode.targetNotMember: 'Esta pessoa não é mais membro do grupo.',
        ErrorCode.cannotRemoveSelf: 'Para sair, use a opção Sair do grupo.',
        ErrorCode.lastAdmin:
            'Promova outro admin antes. O grupo precisa de ao menos um.',
        ErrorCode.groupHasActiveGames:
            'O grupo ainda tem jogos Abertos ou Confirmados.',
      };
      for (final entry in texts.entries) {
        expect(
          errorText(l10nPt, entry.key),
          entry.value,
          reason: entry.key.name,
        );
      }
    },
  );
  test('E15: os textos dos erros de jogo das etapas A a C são os do catálogo '
      '(docs/copy.md, 8.8)', () {
    const texts = {
      ErrorCode.notGameAdmin: 'Só um admin do jogo pode fazer isso.',
      ErrorCode.invalidGameDates:
          'O prazo não pode passar do início, e o início precisa ser antes '
          'do fim.',
      ErrorCode.startInPast: 'O início precisa estar no futuro.',
      ErrorCode.receiverNeedsPixKey: 'O recebedor precisa ter uma chave Pix.',
      ErrorCode.noGameAccess:
          'Para entrar neste jogo, você precisa ser membro do grupo ou ter o '
          'convite.',
      ErrorCode.gameNotOpen: 'Este jogo já foi cancelado ou concluído.',
      ErrorCode.gameFull:
          'A lista encheu. Você pode entrar na lista de espera.',
      ErrorCode.gameNotFull:
          'Abriu uma vaga. Você pode entrar direto na lista.',
      ErrorCode.gameStarted: 'O jogo já começou.',
      ErrorCode.alreadyParticipant: 'Você já está na lista.',
      ErrorCode.alreadyOnWaitlist: 'Você já está na lista de espera.',
      ErrorCode.slotLimitBelowParticipants:
          'O limite não pode ficar abaixo do número de pessoas na lista.',
      // Etapa B.
      ErrorCode.listLocked: 'A lista está travada até a conclusão do jogo.',
      ErrorCode.notOnWaitlist: 'Você não está na lista de espera.',
      ErrorCode.notParticipant: 'Esta pessoa não está mais na lista.',
      ErrorCode.receiverLocked: 'O recebedor não pode sair da lista.',
      // Etapa C.
      ErrorCode.adminMustBeParticipant:
          'Só quem está na lista pode ser admin do jogo.',
      ErrorCode.alreadyGameAdmin: 'Esta pessoa já é admin do jogo.',
      ErrorCode.notGameAdminTarget: 'Esta pessoa não é mais admin do jogo.',
      ErrorCode.lastGameAdmin:
          'Indique outro admin antes. O jogo precisa de ao menos um.',
      ErrorCode.memberIsReceiver:
          'Há jogos em aberto deste grupo com esta pessoa como recebedora.',
      ErrorCode.memberIsOnlyGameAdmin:
          'Há jogos em aberto deste grupo com esta pessoa como única admin.',
    };
    for (final entry in texts.entries) {
      expect(errorText(l10nPt, entry.key), entry.value, reason: entry.key.name);
    }
  });

  test('E15 (fatia 5, etapa A): textos dos erros da conclusão '
      '(docs/copy.md, 9.6)', () {
    const texts = {
      ErrorCode.gameNotEnded:
          'O jogo só pode ser concluído a partir do horário de fim.',
      ErrorCode.absentNotParticipant:
          'A lista mudou. Confira as faltas de novo.',
      ErrorCode.receiverCannotBeAbsent:
          'O recebedor não pode ser marcado como faltoso.',
    };
    for (final entry in texts.entries) {
      expect(errorText(l10nPt, entry.key), entry.value, reason: entry.key.name);
    }
  });

  test('E15 (fatia 5, etapa B): textos dos erros da isenção '
      '(docs/copy.md, 9.6)', () {
    const texts = {
      ErrorCode.notAPenalty: 'Só multas podem ser isentadas.',
      ErrorCode.chargeNotPending: 'Este valor não está mais Pendente.',
    };
    for (final entry in texts.entries) {
      expect(errorText(l10nPt, entry.key), entry.value, reason: entry.key.name);
    }
  });

  test('E15 (fatia 5, etapa C): textos dos erros da troca de recebedor '
      '(docs/copy.md, 9.6)', () {
    const texts = {
      ErrorCode.gameCancelled: 'Este jogo foi cancelado.',
      ErrorCode.receiverMustBeParticipant:
          'O novo recebedor precisa estar na lista.',
      ErrorCode.receiverUnchanged: 'Esta pessoa já é a recebedora do jogo.',
      ErrorCode.receiverChangeBlocked:
          'Há valores Em análise. Decida-os antes de trocar o recebedor.',
    };
    for (final entry in texts.entries) {
      expect(errorText(l10nPt, entry.key), entry.value, reason: entry.key.name);
    }
  });

  test('E15 (fatia 6, etapa A): textos dos erros do pagamento manual '
      '(docs/copy.md, 10.7)', () {
    const texts = {
      ErrorCode.notChargeReceiver:
          'Só o recebedor deste valor pode fazer isso.',
      ErrorCode.chargeNotRevertible: 'Este pagamento não pode ser revertido.',
    };
    for (final entry in texts.entries) {
      expect(errorText(l10nPt, entry.key), entry.value, reason: entry.key.name);
    }
  });
}
