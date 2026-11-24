// Concorrência na lista de presença (RN53), fatia 4, etapas A a C.
// Cenários C01 a C07 de docs/testes-referencia.md, seção 8, e C16 da seção
// 12.5 (etapa C).
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
import { concurrencyFixture, gameState, newGame, outcomes, rejoinGroup, rpc } from './support.ts';

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

Deno.test('C03: a espera disputa a vaga aberta pelo aumento do limite', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const owner = accounts[0];
  // conc-00 e conc-01 a conc-04: lista cheia com limite 5; conc-05 a conc-09 na espera.
  const fillers = accounts.slice(1, 5);
  const waiting = accounts.slice(5, 10);
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 5, fillers);
    for (const account of waiting) {
      const queued = await rpc(account.client, 'join_waitlist', { p_game_id: gameId });
      if (queued.error) throw new Error(`${account.email}: ${queued.error.message}`);
    }
    const raised = await rpc(owner.client, 'set_slot_limit', {
      p_game_id: gameId,
      p_slot_limit: 6,
    });
    assertEquals(raised.error, null, `repetition ${i}: limit raised`);
    const calls = await Promise.all(
      waiting.map((account) => rpc(account.client, 'join_game', { p_game_id: gameId })),
    );
    assertEquals(
      outcomes(calls),
      ['GAME_FULL', 'GAME_FULL', 'GAME_FULL', 'GAME_FULL', 'ok'],
      `repetition ${i}`,
    );
    assertEquals(
      await gameState(fixture, gameId),
      { occupied: 6, slotLimit: 6, status: 'confirmed' },
      `repetition ${i}: 6 occupied and confirmed`,
    );
    const winner = waiting[calls.findIndex((call) => call.error === null)];
    const { data: rows, error } = await owner.client
      .from('game_waitlist')
      .select('user_id, left_at')
      .eq('game_id', gameId);
    if (error) throw new Error(`Could not read the waitlist: ${error.message}`);
    for (const row of rows) {
      assertEquals(
        row.left_at !== null,
        row.user_id === winner.id,
        `repetition ${i}: only the winner left the waitlist (RN54)`,
      );
    }
  }
});

Deno.test('C06: uma saída e uma entrada ao mesmo tempo, com a lista cheia', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  // conc-00 e conc-01 a conc-04: lista cheia com limite 5; conc-04 sai e conc-05 entra.
  const fillers = accounts.slice(1, 5);
  const leaver = accounts[4];
  const joiner = accounts[5];
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 5, fillers);
    const [leave, join] = await Promise.all([
      rpc(leaver.client, 'leave_game', { p_game_id: gameId }),
      rpc(joiner.client, 'join_game', { p_game_id: gameId }),
    ]);
    assertEquals(leave.error, null, `repetition ${i}: the leave always works`);
    const state = await gameState(fixture, gameId);
    if (join.error === null) {
      // A saída veio antes e a entrada ocupou a vaga.
      assertEquals(state, { occupied: 5, slotLimit: 5, status: 'confirmed' }, `repetition ${i}`);
    } else {
      // A entrada veio antes e encontrou a lista cheia.
      assertEquals(join.error.message, 'GAME_FULL', `repetition ${i}`);
      assertEquals(state, { occupied: 4, slotLimit: 5, status: 'open' }, `repetition ${i}`);
    }
    assert(state.occupied <= state.slotLimit, `repetition ${i}: never occupied > limit`);
  }
});

Deno.test('C07: uma entrada e o cancelamento ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const owner = accounts[0];
  const joiner = accounts[1];
  for (let i = 0; i < REPETITIONS; i++) {
    const gameId = await newGame(fixture, 10, []);
    const [join, cancel] = await Promise.all([
      rpc(joiner.client, 'join_game', { p_game_id: gameId }),
      rpc(owner.client, 'cancel_game', { p_game_id: gameId }),
    ]);
    assertEquals(cancel.error, null, `repetition ${i}: the cancel always works`);
    if (join.error !== null) {
      // A entrada veio depois.
      assertEquals(join.error.message, 'GAME_NOT_OPEN', `repetition ${i}`);
    }
    assertEquals(
      (await gameState(fixture, gameId)).status,
      'cancelled',
      `repetition ${i}: the game ends cancelled`,
    );
  }
});

Deno.test('C16: uma entrada no jogo e a saída do grupo ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const owner = accounts[0];
  const bruno = accounts[26];
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      await rejoinGroup(fixture, bruno);
      const gameId = await newGame(fixture, 10, []);
      const [join, leave] = await Promise.all([
        rpc(bruno.client, 'join_game', { p_game_id: gameId }),
        rpc(bruno.client, 'leave_group', { p_group_id: fixture.groupId }),
      ]);
      assertEquals(leave.error, null, `repetition ${i}: the leave always works`);
      const gamesLeft = (leave.data as { games_left: string[] }).games_left;
      if (join.error === null) {
        // A entrada venceu, e a saída a retirou.
        assert(gamesLeft.includes(gameId), `repetition ${i}: the game is in games_left`);
      } else {
        // A saída venceu: sem passagem, ele não pode mais ver o jogo.
        assertEquals(join.error.message, 'NOT_FOUND', `repetition ${i}`);
        assertEquals(gamesLeft, [], `repetition ${i}`);
      }
      const { count, error } = await owner.client
        .from('game_participants')
        .select('id', { count: 'exact', head: true })
        .eq('game_id', gameId)
        .eq('user_id', bruno.id)
        .eq('status', 'active');
      if (error) throw new Error(`Could not count: ${error.message}`);
      assertEquals(count, 0, `repetition ${i}: never active without being a member`);
    }
  } finally {
    await rejoinGroup(fixture, bruno);
  }
});
