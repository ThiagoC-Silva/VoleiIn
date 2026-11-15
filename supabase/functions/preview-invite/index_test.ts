// Prévia do convite de grupo (`preview-invite`, docs/contratos-api.md, seção 8).
// Cenários Q01 a Q07 de docs/testes-referencia.md, seção 11.4.
//
// Roda contra a função servida pelo Supabase local, com o seed (docs/setup.md,
// seção 8). A chave secreta local só serve ao Q07, para contar as linhas que o
// app não lê nesta fatia (notifications):
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave> \
//     SUPABASE_SECRET_KEY=<chave> deno test --allow-net --allow-env
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from '@std/assert';

const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
const secretKey = Deno.env.get('SUPABASE_SECRET_KEY');
if (!key || !secretKey) {
  throw new Error(
    'Missing SUPABASE_PUBLISHABLE_KEY or SUPABASE_SECRET_KEY (see docs/setup.md, section 5).',
  );
}

const QUINTA = '00000000-0000-0000-0000-000000000101';
const PASSWORD = 'voleiin123';
const clientOptions = { auth: { persistSession: false, autoRefreshToken: false } };

async function signIn(email: string): Promise<SupabaseClient> {
  const client = createClient(url, key!, clientOptions);
  const { error } = await client.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw new Error(`Could not sign in ${email}: ${error.message}`);
  return client;
}

type Preview = {
  kind: string;
  group_id: string;
  name: string;
  photo_url: string | null;
  is_member: boolean;
  has_pending_request: boolean;
};

type Result = { status: number; body: Record<string, unknown> };

// Chama a função e devolve o HTTP e o corpo, com sucesso ou erro.
async function preview(client: SupabaseClient, body: Record<string, unknown>): Promise<Result> {
  const { data, error } = await client.functions.invoke('preview-invite', { body });
  if (!error) return { status: 200, body: data };
  const response = (error as { context?: Response }).context;
  assert(response instanceof Response, `unexpected error: ${error.message}`);
  return { status: response.status, body: await response.json() };
}

function errorCode(result: Result): unknown {
  return (result.body.error as { code?: string } | undefined)?.code;
}

const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test('prévia do convite de grupo (preview-invite)', options, async (t) => {
  const ana = await signIn('ana@voleiin.test');
  const bruno = await signIn('bruno@voleiin.test');
  const diego = await signIn('diego@voleiin.test');
  const service = createClient(url, secretKey!, clientOptions);

  try {
    await t.step('Q01: Diego vê o Quinta, sem ser membro nem ter pedido', async () => {
      const result = await preview(diego, { code: 'VoleiQuinta1', kind: 'group' });
      assertEquals(result.status, 200);
      assertEquals(result.body as Preview, {
        kind: 'group',
        group_id: QUINTA,
        name: 'Vôlei de Quinta',
        photo_url: null,
        is_member: false,
        has_pending_request: false,
      });
    });

    await t.step('Q02: Bruno é membro', async () => {
      const result = await preview(bruno, { code: 'VoleiQuinta1', kind: 'group' });
      assertEquals(result.status, 200);
      assertEquals((result.body as Preview).is_member, true);
    });

    await t.step('Q03: Diego tem pedido pendente no Domingo', async () => {
      const result = await preview(diego, { code: 'VoleiDomingo', kind: 'group' });
      assertEquals(result.status, 200);
      assertEquals((result.body as Preview).has_pending_request, true);
      assertEquals((result.body as Preview).is_member, false);
    });

    await t.step('Q04: outra caixa e código inexistente dão 404 INVITE_INVALID', async () => {
      for (const code of ['voleiquinta1', 'VoleiQuinta2']) {
        const result = await preview(diego, { code, kind: 'group' });
        assertEquals(result.status, 404, code);
        assertEquals(errorCode(result), 'INVITE_INVALID', code);
      }
    });

    await t.step('Q05: sem login, sem código e kind game', async () => {
      const anonymous = createClient(url, key!, clientOptions);
      const noLogin = await preview(anonymous, { code: 'VoleiQuinta1', kind: 'group' });
      assertEquals(noLogin.status, 401);
      assertEquals(errorCode(noLogin), 'NOT_AUTHENTICATED');

      const noCode = await preview(diego, { kind: 'group' });
      assertEquals(noCode.status, 422);
      assertEquals(errorCode(noCode), 'INVALID_INPUT');

      const game = await preview(diego, { code: 'VoleiQuinta1', kind: 'game' });
      assertEquals(game.status, 422);
      assertEquals(errorCode(game), 'INVALID_INPUT');
    });

    await t.step('Q06: a foto do grupo vem como URL assinada que baixa o arquivo', async () => {
      const photo = `groups/${QUINTA}/${crypto.randomUUID()}.png`;
      const bytes = new Uint8Array(2048).fill(7);
      const upload = await ana.storage.from('avatars').upload(photo, bytes, {
        contentType: 'image/png',
        upsert: false,
      });
      assertEquals(upload.error, null);
      const update = await ana.rpc('update_group', {
        p_group_id: QUINTA,
        p_name: 'Vôlei de Quinta',
        p_photo_path: photo,
      });
      assertEquals(update.error, null);

      try {
        const result = await preview(diego, { code: 'VoleiQuinta1', kind: 'group' });
        assertEquals(result.status, 200);
        const photoUrl = (result.body as Preview).photo_url;
        assert(photoUrl, 'photo_url should be a signed URL');
        const download = await fetch(photoUrl);
        assertEquals(download.status, 200);
        assertEquals((await download.arrayBuffer()).byteLength, bytes.byteLength);
      } finally {
        await ana.rpc('update_group', {
          p_group_id: QUINTA,
          p_name: 'Vôlei de Quinta',
          p_photo_path: null,
        });
        await ana.storage.from('avatars').remove([photo]);
      }
    });

    await t.step('Q07: a prévia não grava nada', async () => {
      const count = async (table: string) => {
        const { count, error } = await service.from(table).select('*', {
          count: 'exact',
          head: true,
        });
        assertEquals(error, null, table);
        return count;
      };
      const requestsBefore = await count('group_join_requests');
      const notificationsBefore = await count('notifications');

      const result = await preview(diego, { code: 'VoleiQuinta1', kind: 'group' });
      assertEquals(result.status, 200);

      assertEquals(await count('group_join_requests'), requestsBefore);
      assertEquals(await count('notifications'), notificationsBefore);
    });
  } finally {
    await ana.auth.signOut();
    await bruno.auth.signOut();
    await diego.auth.signOut();
  }
});
