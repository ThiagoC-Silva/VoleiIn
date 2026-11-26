import 'package:voleiin/features/auth/domain/pix_key.dart';
import 'package:voleiin/features/games/domain/charge_models.dart';
import 'package:voleiin/features/games/domain/game_models.dart';

import 'groups_fixtures.dart';
import 'harness.dart';

// Jogos dos cenários de docs/testes-referencia.md, seção 12.6, e dos PNGs de
// docs/ui/referencias/fatia-4/, com os IDs do seed (docs/setup.md, seção 8).
// O relógio do harness está em 16/11/2026, antes de todos eles.

const game1Id = '00000000-0000-0000-0000-000000000201';
const game2Id = '00000000-0000-0000-0000-000000000202';
const standaloneId = '00000000-0000-0000-0000-000000000207';
const cancelledId = '00000000-0000-0000-0000-000000000204';
const edId = '00000000-0000-0000-0000-00000000000e';

/// Sábado, 21/11/2026, 20:00 em Fortaleza.
final game1Start = DateTime.utc(2026, 11, 21, 23);

/// Sábado, 21/11/2026, 22:00 em Fortaleza.
final game1End = DateTime.utc(2026, 11, 22, 1);

/// Sexta, 20/11/2026, 18:00 em Fortaleza.
final game1Deadline = DateTime.utc(2026, 11, 20, 21);

GameParticipant participant(
  String userId,
  String displayName, {
  int minute = 0,
  ParticipantStatus status = ParticipantStatus.active,
}) => GameParticipant(
  userId: userId,
  displayName: displayName,
  status: status,
  joinedAt: DateTime.utc(2026, 11, 16, 13, minute),
);

WaitlistEntry waiting(String userId, String displayName, {int minute = 0}) =>
    WaitlistEntry(
      userId: userId,
      displayName: displayName,
      joinedAt: DateTime.utc(2026, 11, 16, 14, minute),
    );

/// Ana, Brunão e Carlinha, na ordem de entrada.
List<GameParticipant> game1Participants() => [
  participant(anaId, 'Ana'),
  participant(brunoId, 'Brunão', minute: 5),
  participant(carlaId, 'Carlinha', minute: 9),
];

/// O jogo 1 dos PNGs: Vôlei de Quinta, Quadra do Sesc, sáb 21/11 das 20:00
/// às 22:00, prazo sex 20/11 18:00, R$ 120,00 e 12 vagas, com Ana (admin e
/// recebedora, chave CPF), Brunão e Carlinha. Por padrão, visto pela Ana.
GameDetail game1({
  String viewerId = anaId,
  String id = game1Id,
  String? groupId = quintaId,
  String? groupName = quintaName,
  String locationName = 'Quadra do Sesc',
  String? mapsUrl = 'https://maps.app.goo.gl/Sesc21',
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? cancellationDeadline,
  int totalCents = 12000,
  int slotLimit = 12,
  GameStatus status = GameStatus.open,
  String receiverId = anaId,
  String receiverName = 'Ana',
  PixKeyType? pixKeyType = PixKeyType.cpf,
  String? pixKey = '12345678909',
  List<GameParticipant>? participants,
  List<WaitlistEntry> waitlist = const [],
  List<String> adminIds = const [anaId],
  bool isGroupMember = true,
}) => GameDetail(
  id: id,
  groupId: groupId,
  groupName: groupName,
  locationName: locationName,
  mapsUrl: mapsUrl,
  cancellationDeadline: cancellationDeadline ?? game1Deadline,
  startsAt: startsAt ?? game1Start,
  endsAt: endsAt ?? game1End,
  totalCents: totalCents,
  slotLimit: slotLimit,
  status: status,
  receiverId: receiverId,
  receiverName: receiverName,
  receiverPixKeyType: pixKeyType,
  receiverPixKey: pixKey,
  participants: participants ?? game1Participants(),
  waitlist: waitlist,
  adminIds: adminIds,
  isGroupMember: isGroupMember,
  viewerId: viewerId,
);

/// O jogo 2 dos PNGs: Ginásio Verdão, dom 22/11 das 20:00 às 22:00, prazo
/// dom 22/11 18:00, R$ 60,00 e 2 vagas, Confirmado, com Ana e Carlinha na
/// lista e Brunão na espera.
GameDetail game2({
  String viewerId = anaId,
  List<WaitlistEntry>? waitlist,
  bool isGroupMember = true,
}) => game1(
  viewerId: viewerId,
  id: game2Id,
  locationName: 'Ginásio Verdão',
  mapsUrl: null,
  startsAt: DateTime.utc(2026, 11, 22, 23),
  endsAt: DateTime.utc(2026, 11, 23, 1),
  cancellationDeadline: DateTime.utc(2026, 11, 22, 21),
  totalCents: 6000,
  slotLimit: 2,
  status: GameStatus.confirmed,
  participants: [participant(anaId, 'Ana'), participant(carlaId, 'Carlinha')],
  waitlist: waitlist ?? [waiting(brunoId, 'Brunão')],
  isGroupMember: isGroupMember,
);

GameSummary summary({
  String id = game1Id,
  String? groupName = quintaName,
  String locationName = 'Quadra do Sesc',
  DateTime? startsAt,
  GameStatus status = GameStatus.open,
  int slotLimit = 12,
  int occupiedSlots = 3,
  ParticipantStatus? myStatus,
  int? myWaitlistPosition,
}) {
  final start = startsAt ?? game1Start;
  return GameSummary(
    id: id,
    groupName: groupName,
    locationName: locationName,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: status,
    slotLimit: slotLimit,
    occupiedSlots: occupiedSlots,
    myStatus: myStatus,
    myWaitlistPosition: myWaitlistPosition,
  );
}

const quintaOption = GameGroupOption(id: quintaId, name: quintaName);
const areiaOption = GameGroupOption(id: areiaId, name: 'Areia do Rio');

// Fatia 5 (docs/testes-referencia.md, seção 13; PNGs de
// docs/ui/referencias/fatia-5/). O jogo terminou no domingo, 15/11/2026, às
// 22:00 em Fortaleza: o relógio do harness (16/11, 12:00) está depois do fim.

const finishedId = '00000000-0000-0000-0000-000000000208';
const daviId = '00000000-0000-0000-0000-0000000000d1';
const eduId = '00000000-0000-0000-0000-0000000000e1';
const fabioId = '00000000-0000-0000-0000-0000000000f1';

/// Domingo, 15/11/2026, 20:00 em Fortaleza.
final finishedStart = DateTime.utc(2026, 11, 15, 23);

/// Domingo, 15/11/2026, 22:00 em Fortaleza.
final finishedEnd = DateTime.utc(2026, 11, 16, 1);

/// As outras sete pessoas da lista do R01, com IDs de teste.
const _r01Others = [
  ('Gabi', '00000000-0000-0000-0000-0000000000a2'),
  ('Hugo', '00000000-0000-0000-0000-0000000000a3'),
  ('Iara', '00000000-0000-0000-0000-0000000000a4'),
  ('João', '00000000-0000-0000-0000-0000000000a5'),
  ('Kátia', '00000000-0000-0000-0000-0000000000a6'),
  ('Lara', '00000000-0000-0000-0000-0000000000a7'),
];

/// A lista do R01 no fim: Ana, Bruno, Edu (faltou), Fábio e mais seis, dez de
/// doze vagas.
List<GameParticipant> r01Participants({bool eduAbsent = true}) => [
  participant(anaId, 'Ana'),
  participant(brunoId, 'Brunão', minute: 1),
  participant(eduId, 'Edu', minute: 2).copyWith(absent: eduAbsent),
  participant(fabioId, 'Fábio', minute: 3),
  for (var i = 0; i < _r01Others.length; i++)
    participant(_r01Others[i].$2, _r01Others[i].$1, minute: 4 + i),
];

GameCharge charge(
  String payerId,
  String payerName, {
  ChargeKind kind = ChargeKind.share,
  int amountCents = 2084,
  ChargeStatus status = ChargeStatus.pending,
  String receiverId = anaId,
  String receiverName = 'Ana',
  ChargeWaiveReason? waiveReason,
  PaymentMethod? paidVia,
  String? reviewReceiptId,
}) => GameCharge(
  id: 'charge-$payerId',
  payerId: payerId,
  payerName: payerName,
  receiverId: receiverId,
  receiverName: receiverName,
  kind: kind,
  amountCents: amountCents,
  status: status,
  waiveReason: waiveReason,
  paidVia: paidVia,
  reviewReceiptId: reviewReceiptId,
);

/// O jogo do R01: Quadra do Sesc, R$ 250,00, 12 vagas, depois do fim. Por
/// padrão, Aberto e visto pela Ana.
GameDetail finishedGame({
  String viewerId = anaId,
  GameStatus status = GameStatus.open,
  int? shareCents,
  GameCharge? myCharge,
  List<GameParticipant>? participants,
  List<String> adminIds = const [anaId],
}) => game1(
  viewerId: viewerId,
  id: finishedId,
  startsAt: finishedStart,
  endsAt: finishedEnd,
  cancellationDeadline: DateTime.utc(2026, 11, 15, 21),
  totalCents: 25000,
  status: status,
  participants: participants ?? r01Participants(),
  adminIds: adminIds,
).copyWith(shareCents: shareCents, myCharge: myCharge);

/// O R01 concluído: parte de R$ 20,84.
GameDetail completedGame({String viewerId = anaId, GameCharge? myCharge}) =>
    finishedGame(
      viewerId: viewerId,
      status: GameStatus.completed,
      shareCents: 2084,
      myCharge: myCharge,
    );

/// O *preview* do R01: R$ 20,84, R$ 229,24 a receber, R$ 20,76 por conta da
/// Ana, uma multa isentada.
const r01Preview = CompletionPreview(
  shareCents: 2084,
  totalToReceiveCents: 22924,
  receiverCoveredCents: 2076,
  uncoveredSlots: 0,
  penaltiesExempted: 1,
);
