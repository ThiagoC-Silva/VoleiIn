// Concorrência nos pagamentos (fatia 6). Cenários C09 (etapa A), C10 a C12 e
// C18 (etapa B) de docs/testes-referencia.md, seções 8 e 14.7.
//
// C10 a C12 e C18 usam as contas e o jogo de process-receipt/test_support.ts
// (research R10 de specs/010-pagamentos-etapa-b): record_receipt é chamada
// direto, como service_role, com a leitura pronta.
//
// Cada repetição cria um jogo da conc-00, leva as datas para o passado por uma
// conexão de postgres e o conclui com a falta da conc-02. A conc-01, também
// admin do jogo, isenta a multa, e a conc-00, a recebedora, a marca como paga,
// ao mesmo tempo (research R7 de specs/009-pagamentos-etapa-a).
//
//   SUPABASE_DB_URL=... (padrão: o banco local) mais as variáveis de support.ts.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from '@std/assert';
import postgres from 'postgres';
import { concurrencyFixture, newGame, outcomes, rpc } from './support.ts';
import {
  closeWorld,
  newGame as newReceiptGame,
  type Person,
  publishableKey,
  receiptWorld,
  supabaseUrl,
  type World,
} from '../../process-receipt/test_support.ts';

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

// Etapa B ---------------------------------------------------------------------

function clientOf(person: Person): SupabaseClient {
  return createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${person.token}` } },
  });
}

// Um código do Pix válido e novo (RN88d).
function transactionId(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const tail = Array.from(crypto.getRandomValues(new Uint8Array(11)), (b) => chars[b % 36]);
  return `E11122233202611200115${tail.join('')}`;
}

// A leitura boa da seção 14, com o ID e as mudanças pedidas.
function goodReading(transaction: string, changes: Record<string, unknown> = {}) {
  return {
    outcome: 'read',
    amount_cents: 2084,
    paid_at: '2026-11-19T22:15',
    recipient_name: 'ANA SOUZA LIMA',
    recipient_key: null,
    transaction_id: transaction,
    raw: {},
    ...changes,
  };
}

// record_receipt como a process-receipt a chama.
function record(w: World, chargeId: string, payer: Person, reading: unknown) {
  return rpc(w.service, 'record_receipt', {
    p_charge_id: chargeId,
    p_payer_id: payer.id,
    p_storage_path: `${chargeId}/${crypto.randomUUID()}.jpg`,
    p_mime_type: 'image/jpeg',
    p_size_bytes: 200000,
    p_reading: reading,
  });
}

type Recorded = { receipt_id: string; result: string; error_code: string | null };

Deno.test('C10: o mesmo ID em dois valores, ao mesmo tempo', options, async () => {
  const w = await receiptWorld();
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const [first, second] = [await newReceiptGame(w), await newReceiptGame(w)];
      const id = transactionId();
      const calls = await Promise.all([
        record(w, first.fabioCharge, w.fabio, goodReading(id)),
        record(w, second.brunoCharge, w.bruno, goodReading(id)),
      ]);
      assertEquals(calls.map((c) => c.error), [null, null], `repetition ${i}: no error`);
      const results = calls.map((c) => c.data as Recorded);
      assertEquals(
        results.map((r) => `${r.result} ${r.error_code}`).sort(),
        ['approved null', 'rejected DUPLICATE_TRANSACTION'],
        `repetition ${i}: one is recorded, the other is a duplicate (RN89)`,
      );
    }
  } finally {
    await closeWorld();
  }
});

Deno.test('C11: dois envios para o mesmo valor', options, async () => {
  const w = await receiptWorld();
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const game = await newReceiptGame(w);
      const calls = await Promise.all([
        record(w, game.fabioCharge, w.fabio, goodReading(transactionId())),
        record(w, game.fabioCharge, w.fabio, goodReading(transactionId())),
      ]);
      assertEquals(outcomes(calls), ['CHARGE_NOT_PENDING', 'ok'], `repetition ${i}`);
      const [state] = await w.sql`
        select c.status::text,
               (select count(*)::int from public.receipts r where r.charge_id = c.id) as receipts
        from public.charges c where c.id = ${game.fabioCharge}`;
      assertEquals({ ...state }, { status: 'paid', receipts: 1 }, `repetition ${i}`);
    }
  } finally {
    await closeWorld();
  }
});

Deno.test('C12: troca de recebedor e envio ao mesmo tempo', options, async () => {
  const w = await receiptWorld();
  const ana = clientOf(w.ana);
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const game = await newReceiptGame(w);
      const [change, sent] = await Promise.all([
        rpc(ana, 'change_receiver', { p_game_id: game.gameId, p_new_receiver_id: w.bruno.id }),
        record(w, game.fabioCharge, w.fabio, goodReading(transactionId())),
      ]);
      assertEquals(sent.error, null, `repetition ${i}: the receipt is recorded`);
      const [receipt] = await w.sql`
        select r.status::text, r.receiver_id, c.receiver_id as charge_receiver, c.status::text as charge_status
        from public.receipts r join public.charges c on c.id = r.charge_id
        where r.id = ${(sent.data as Recorded).receipt_id}`;
      if (change.error) {
        assertEquals(change.error.message, 'RECEIVER_CHANGE_BLOCKED', `repetition ${i}`);
        assertEquals(
          [receipt.status, receipt.receiver_id],
          ['under_review', w.ana.id],
          `repetition ${i}`,
        );
      } else if (receipt.status === 'approved') {
        // O comprovante venceu: Pago à Ana, que fica com ele depois da troca.
        assertEquals(
          [receipt.receiver_id, receipt.charge_receiver, receipt.charge_status],
          [w.ana.id, w.ana.id, 'paid'],
          `repetition ${i}`,
        );
      } else {
        // A troca venceu: conferido contra o Bruno, o nome lido não confere.
        assertEquals(
          [receipt.status, receipt.receiver_id, receipt.charge_receiver],
          ['under_review', w.bruno.id, w.bruno.id],
          `repetition ${i}`,
        );
      }
    }
  } finally {
    await closeWorld();
  }
});

Deno.test('C18: aprovar e recusar o mesmo comprovante ao mesmo tempo', options, async () => {
  const w = await receiptWorld();
  const ana = clientOf(w.ana);
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const game = await newReceiptGame(w);
      const sent = await record(
        w,
        game.fabioCharge,
        w.fabio,
        goodReading(transactionId(), { amount_cents: null }),
      );
      const receiptId = (sent.data as Recorded).receipt_id;
      assert(receiptId, `repetition ${i}: the receipt under review`);
      const [approve, reject] = await Promise.all([
        rpc(ana, 'review_receipt', { p_receipt_id: receiptId, p_approve: true, p_note: null }),
        rpc(ana, 'review_receipt', { p_receipt_id: receiptId, p_approve: false, p_note: 'Não.' }),
      ]);
      assertEquals(
        outcomes([approve, reject]),
        ['RECEIPT_NOT_UNDER_REVIEW', 'ok'],
        `repetition ${i}`,
      );
      const [charge] = await w
        .sql`select status::text from public.charges where id = ${game.fabioCharge}`;
      assertEquals(charge.status, approve.error ? 'pending' : 'paid', `repetition ${i}`);
    }
  } finally {
    await closeWorld();
  }
});
