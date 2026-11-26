// Bucket receipts (fatia 6, etapa B). Cenários RS06 a RS08 de
// docs/testes-referencia.md, seção 14.5, com as políticas da rls-matriz.md
// (fatia 6). Cada pessoa usa a API do Storage com o próprio token, como o app.
// Contas e jogo: process-receipt/test_support.ts.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from '@std/assert';
import {
  closeWorld,
  newGame,
  type Person,
  publishableKey,
  receiptWorld,
  supabaseUrl,
  upload,
} from '../process-receipt/test_support.ts';

const options = { sanitizeOps: false, sanitizeResources: false };
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 16, 74, 70, 73, 70, 0, 1]);

function storageOf(person: Person): SupabaseClient {
  return createClient(supabaseUrl, publishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${person.token}` } },
  });
}

async function send(person: Person, path: string, upsert = false): Promise<boolean> {
  const { error } = await storageOf(person).storage.from('receipts').upload(path, JPEG, {
    contentType: 'image/jpeg',
    upsert,
  });
  return !error;
}

async function canSign(person: Person, path: string): Promise<boolean> {
  const { data, error } = await storageOf(person).storage.from('receipts').createSignedUrl(
    path,
    60,
  );
  return !error && !!data?.signedUrl;
}

Deno.test('bucket receipts (RS06 a RS08)', options, async (t) => {
  const w = await receiptWorld();
  try {
    await t.step('RS06: só o pagador de um valor Pendente, no formato certo', async () => {
      const game = await newGame(w);
      const path = () => `${game.fabioCharge}/${crypto.randomUUID()}.jpg`;
      assertEquals(
        [
          await send(w.fabio, path()),
          await send(w.ana, path()),
          await send(w.bruno, path()),
          await send(w.fabio, `${game.brunoCharge}/${crypto.randomUUID()}.jpg`),
          await send(w.fabio, 'nao-e-uuid/x.jpg'),
          await send(w.fabio, `${game.fabioCharge}/sub/${crypto.randomUUID()}.jpg`),
        ],
        [true, false, false, false, false, false],
      );
    });

    await t.step('RS07: valor Pago, sobrescrever e apagar', async () => {
      const game = await newGame(w);
      const old = `${game.fabioCharge}/${crypto.randomUUID()}.jpg`;
      assert(await send(w.fabio, old), 'RS07: o envio com o valor Pendente');
      await w.sql`
        update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
        where id = ${game.fabioCharge}`;
      const sent = await send(w.fabio, `${game.fabioCharge}/${crypto.randomUUID()}.jpg`);
      const overwritten = await send(w.fabio, old, true);
      await storageOf(w.fabio).storage.from('receipts').remove([old]);
      const { data } = await w.service.storage.from('receipts').list(game.fabioCharge);
      assertEquals(
        [sent, overwritten, (data ?? []).map((f) => `${game.fabioCharge}/${f.name}`)],
        [false, false, [old]],
        'RS07: recusado nos três, e o arquivo antigo continua',
      );
    });

    await t.step('RS08: a URL assinada só para o pagador e o recebedor do registro', async () => {
      const game = await newGame(w);
      const withRecord = await upload(w, game.fabioCharge, JPEG, 'image/jpeg', 'jpg');
      const { error } = await w.service.rpc('record_receipt', {
        p_charge_id: game.fabioCharge,
        p_payer_id: w.fabio.id,
        p_storage_path: withRecord,
        p_mime_type: 'image/jpeg',
        p_size_bytes: JPEG.length,
        p_reading: { outcome: 'failed' },
      });
      assertEquals(error, null, 'RS08: o registro do comprovante');
      const withoutRecord = await upload(w, game.brunoCharge, JPEG, 'image/jpeg', 'jpg');
      assertEquals(
        [
          await canSign(w.fabio, withRecord),
          await canSign(w.ana, withRecord),
          await canSign(w.edu, withRecord),
          await canSign(w.diego, withRecord),
          await canSign(w.bruno, withoutRecord),
          await canSign(w.ana, withoutRecord),
        ],
        [true, true, false, false, false, false],
      );
    });
  } finally {
    await closeWorld();
  }
});
