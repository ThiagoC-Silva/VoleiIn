// Concorrência na lista de presença (RN53), fatia 4, etapa A.
// Cenários C01, C02, C04 e C05 de docs/testes-referencia.md, seção 8. C03 e C06
// entram na etapa B, e C07 e C16, na etapa C.
//
// Cada repetição cria um jogo novo da conc-00 no grupo de teste, enche as vagas
// iniciais e dispara as chamadas juntas, por clientes separados: o PostgREST
// atende cada uma numa conexão própria do banco local (research R4 de
// specs/002-grupos e R7 de specs/003-jogo-etapa-a). Os jogos ficam no banco
// local, só com as contas de teste, até o próximo `supabase db reset`.
//
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... SUPABASE_SECRET_KEY=... \
//     SUPABASE_JWT_SECRET=... deno test --allow-net --allow-env
import { assert, assertEquals } from '@std/assert';
import { concurrencyFixture, gameState, newGame, outcomes, rpc } from './support.ts';

const REPETITIONS = 50;
const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test('C01: dois usuários disputam a última vaga', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  // conc-00 e conc-01 a conc-08: 9 de 10 vagas.
  const fillers = accounts.slice(1, 9);
  const [first, second] = [accounts[9], accounts[10]];
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 10, fillers);
    const calls = await Promise.all([
      rpc(first.client, 'join_game', { p_game_id: gameId }),
      rpc(second.client, 'join_game', { p_game_id: gameId }),
    ]);
    assertEquals(outcomes(calls), ['GAME_FULL', 'ok'], `repetition ${i}`);
    assertEquals(
      await gameState(fixture, gameId),
      { occupied: 10, slotLimit: 10, status: 'confirmed' },
      `repetition ${i}: 10 occupied and confirmed`,
    );
  }
});

Deno.test('C02: vinte usuários disputam três vagas', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  // conc-00 e conc-01 a conc-06: 7 de 10 vagas; conc-07 a conc-26 entram juntos.
  const fillers = accounts.slice(1, 7);
  const racers = accounts.slice(7, 27);
  assertEquals(racers.length, 20);
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 10, fillers);
    const calls = await Promise.all(
      racers.map((account) => rpc(account.client, 'join_game', { p_game_id: gameId })),
    );
    const result = outcomes(calls);
    assertEquals(result.filter((o) => o === 'ok').length, 3, `repetition ${i}: exactly 3 joined`);
    assertEquals(
      result.filter((o) => o === 'GAME_FULL').length,
      17,
      `repetition ${i}: 17 got GAME_FULL`,
    );
    assertEquals(
      (await gameState(fixture, gameId)).occupied,
      10,
      `repetition ${i}: 10 occupied`,
    );
  }
});

Deno.test('C04: o mesmo usuário entra duas vezes', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  // conc-00 e conc-01 a conc-04: 5 de 10 vagas.
  const fillers = accounts.slice(1, 5);
  const twice = accounts[5];
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 10, fillers);
    const calls = await Promise.all([
      rpc(twice.client, 'join_game', { p_game_id: gameId }),
      rpc(twice.client, 'join_game', { p_game_id: gameId }),
    ]);
    assertEquals(outcomes(calls), ['ALREADY_PARTICIPANT', 'ok'], `repetition ${i}`);
    assertEquals(
      (await gameState(fixture, gameId)).occupied,
      6,
      `repetition ${i}: one passage created`,
    );
  }
});

Deno.test('C05: uma entrada e a redução do limite ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const owner = accounts[0];
  // conc-00 e conc-01 a conc-08: 9 de 10 vagas.
  const fillers = accounts.slice(1, 9);
  const joiner = accounts[9];
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 10, fillers);
    const [join, reduce] = await Promise.all([
      rpc(joiner.client, 'join_game', { p_game_id: gameId }),
      rpc(owner.client, 'set_slot_limit', { p_game_id: gameId, p_slot_limit: 9 }),
    ]);
    const state = await gameState(fixture, gameId);
    if (join.error === null) {
      // A entrada venceu.
      assertEquals(reduce.error?.message, 'SLOT_LIMIT_BELOW_PARTICIPANTS', `repetition ${i}`);
      assertEquals(state, { occupied: 10, slotLimit: 10, status: 'confirmed' }, `repetition ${i}`);
    } else {
      // A redução venceu.
      assertEquals(join.error.message, 'GAME_FULL', `repetition ${i}`);
      assertEquals(reduce.error, null, `repetition ${i}`);
      assertEquals(state, { occupied: 9, slotLimit: 9, status: 'confirmed' }, `repetition ${i}`);
    }
    assert(state.occupied <= state.slotLimit, `repetition ${i}: never occupied > limit`);
  }
});
