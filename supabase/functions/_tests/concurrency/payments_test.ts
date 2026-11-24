// Concorrência nos pagamentos (fatia 6). Cenário C09 (etapa A) de
// docs/testes-referencia.md, seção 8, com mark_charge_paid.
//
// Cada repetição cria um jogo da conc-00, leva as datas para o passado por uma
// conexão de postgres e o conclui com a falta da conc-02. A conc-01, também
// admin do jogo, isenta a multa, e a conc-00, a recebedora, a marca como paga,
// ao mesmo tempo (research R7 de specs/009-pagamentos-etapa-a).
//
//   SUPABASE_DB_URL=... (padrão: o banco local) mais as variáveis de support.ts.
import { assertEquals } from '@std/assert';
import postgres from 'postgres';
import { concurrencyFixture, newGame, outcomes, rpc } from './support.ts';

const REPETITIONS = 50;
const options = { sanitizeOps: false, sanitizeResources: false };
const dbUrl = Deno.env.get('SUPABASE_DB_URL') ??
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

Deno.test('C09: isenção e marcação de pagamento ao mesmo tempo', options, async () => {
  const fixture = await concurrencyFixture();
  const { accounts } = fixture;
  const [receiver, otherAdmin, absent] = accounts;
  const sql = postgres(dbUrl, { max: 2, onnotice: () => {} });
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const gameId = await newGame(fixture, 10, [otherAdmin, absent]);
      await sql`
        insert into public.game_admins (game_id, user_id, added_by)
        values (${gameId}, ${otherAdmin.id}, ${receiver.id})`;
      await sql`
        update public.games
        set cancellation_deadline = now() - interval '250 minutes',
            starts_at = now() - interval '130 minutes',
            ends_at = now() - interval '10 minutes'
        where id = ${gameId}`;
      const completed = await rpc(receiver.client, 'complete_game', {
        p_game_id: gameId,
        p_absent_user_ids: [absent.id],
      });
      assertEquals(completed.error, null, `repetition ${i}: complete_game`);
      const [{ id: chargeId }] = await sql`
        select id from public.charges
        where game_id = ${gameId} and payer_id = ${absent.id} and kind = 'absence_penalty'`;

      const [waive, pay] = await Promise.all([
        rpc(otherAdmin.client, 'waive_penalty', { p_charge_id: chargeId }),
        rpc(receiver.client, 'mark_charge_paid', { p_charge_id: chargeId }),
      ]);
      assertEquals(
        outcomes([waive, pay]),
        ['CHARGE_NOT_PENDING', 'ok'],
        `repetition ${i}: only one transition counts`,
      );

      const [charge] = await sql`
        select c.status::text,
               (select count(*)::int from public.charge_events e
                where e.charge_id = c.id and e.from_status = 'pending') as transitions
        from public.charges c where c.id = ${chargeId}`;
      assertEquals(
        { ...charge },
        { status: pay.error ? 'waived' : 'paid', transitions: 1 },
        `repetition ${i}`,
      );
    }
  } finally {
    await sql.end();
  }
});
