// Concorrência na conclusão (RN46) e na isenção (RN66), fatia 5. Cenários C08
// (etapa A) e C09 (etapa B) de docs/testes-referencia.md, seção 8, na forma da
// seção 13.5.
//
// Cada repetição cria um jogo novo da conc-00 com três contas na lista, leva as
// datas para o passado (fim 61 minutos antes) por uma conexão de postgres e
// dispara juntas a conclusão manual, pela API, e auto_complete_due_games(),
// pela conexão de postgres (research R6 de specs/006-conclusao-etapa-a).
//
// No C09, a conc-00 e a conc-01, as duas admins do jogo, isentam juntas a mesma
// multa Pendente, pela API (research R2 de specs/007-conclusao-etapa-b).
//
//   SUPABASE_DB_URL=... (padrão: o banco local) mais as variáveis de support.ts.
import { assert, assertEquals } from '@std/assert';
import postgres from 'postgres';
import { concurrencyFixture, newGame, outcomes, rpc } from './support.ts';

const REPETITIONS = 50;
const options = { sanitizeOps: false, sanitizeResources: false };
const dbUrl = Deno.env.get('SUPABASE_DB_URL') ??
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

Deno.test('C08: conclusão manual e automática ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const owner = accounts[0];
  const fillers = accounts.slice(1, 4);
  const sql = postgres(dbUrl, { max: 2, onnotice: () => {} });
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const gameId = await newGame(fixture, 10, fillers);
      await sql`
        update public.games
        set cancellation_deadline = now() - interval '301 minutes',
            starts_at = now() - interval '181 minutes',
            ends_at = now() - interval '61 minutes'
        where id = ${gameId}`;

      const [manual] = await Promise.all([
        rpc(owner.client, 'complete_game', { p_game_id: gameId }),
        sql`select public.auto_complete_due_games()`,
      ]);
      const outcome = manual.error?.message ?? 'ok';
      assert(
        outcome === 'ok' || outcome === 'GAME_NOT_OPEN',
        `repetition ${i}: manual got ${outcome}`,
      );

      const [game] = await sql`
        select status::text, completion_mode::text as mode,
               (select count(*)::int from public.charges where game_id = g.id) as charges,
               (select count(*)::int from public.audit_log
                where entity_id = g.id and event = 'game_completed') as audits
        from public.games g where g.id = ${gameId}`;
      assertEquals(
        { ...game },
        {
          status: 'completed',
          mode: outcome === 'ok' ? 'manual' : 'automatic',
          charges: 3,
          audits: 1,
        },
        `repetition ${i}: one completion, values created once`,
      );
    }
  } finally {
    await sql.end();
  }
});

Deno.test('C09: duas isenções da mesma multa ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const [owner, otherAdmin, absent] = accounts;
  const sql = postgres(dbUrl, { max: 2, onnotice: () => {} });
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const gameId = await newGame(fixture, 10, [otherAdmin, absent]);
      await sql`
        insert into public.game_admins (game_id, user_id, added_by)
        values (${gameId}, ${otherAdmin.id}, ${owner.id})`;
      await sql`
        update public.games
        set cancellation_deadline = now() - interval '250 minutes',
            starts_at = now() - interval '130 minutes',
            ends_at = now() - interval '10 minutes'
        where id = ${gameId}`;
      const completed = await rpc(owner.client, 'complete_game', {
        p_game_id: gameId,
        p_absent_user_ids: [absent.id],
      });
      assertEquals(completed.error, null, `repetition ${i}: complete_game`);
      const [{ id: chargeId }] = await sql`
        select id from public.charges
        where game_id = ${gameId} and payer_id = ${absent.id} and kind = 'absence_penalty'`;

      const calls = await Promise.all([
        rpc(owner.client, 'waive_penalty', { p_charge_id: chargeId }),
        rpc(otherAdmin.client, 'waive_penalty', { p_charge_id: chargeId }),
      ]);
      assertEquals(
        outcomes(calls).sort(),
        ['CHARGE_NOT_PENDING', 'ok'],
        `repetition ${i}: only one waiver counts`,
      );

      const [charge] = await sql`
        select c.status::text,
               (select count(*)::int from public.charge_events e
                where e.charge_id = c.id and e.to_status = 'waived') as waivers
        from public.charges c where c.id = ${chargeId}`;
      assertEquals({ ...charge }, { status: 'waived', waivers: 1 }, `repetition ${i}`);
    }
  } finally {
    await sql.end();
  }
});
