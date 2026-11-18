// Concorrência na conclusão (RN46), fatia 5, etapa A. Cenário C08 de
// docs/testes-referencia.md, seção 8, na forma da seção 13.5.
//
// Cada repetição cria um jogo novo da conc-00 com três contas na lista, leva as
// datas para o passado (fim 61 minutos antes) por uma conexão de postgres e
// dispara juntas a conclusão manual, pela API, e auto_complete_due_games(),
// pela conexão de postgres (research R6 de specs/006-conclusao-etapa-a).
//
//   SUPABASE_DB_URL=... (padrão: o banco local) mais as variáveis de support.ts.
import { assert, assertEquals } from '@std/assert';
import postgres from 'postgres';
import { concurrencyFixture, newGame, rpc } from './support.ts';

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
