// Fotos de perfil no bucket avatars (fatia 2).
// Cenários A01 a A06 de docs/testes-referencia.md, seção 10.3; RN106.
//
// Roda contra a API do Storage local, com a Ana e o Bruno do seed logados por
// e-mail e senha (docs/setup.md, seção 8). O Storage confere o tipo declarado no
// envio e o tamanho; o app garante o tipo real ao redimensionar.
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave> \
//     deno test --allow-net --allow-env _tests/

import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from 'jsr:@std/assert@1';

const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? '';

const ANA = '00000000-0000-0000-0000-00000000000a';
const BRUNO = '00000000-0000-0000-0000-00000000000b';
const MAX_BYTES = 2_097_152;

async function signIn(email: string): Promise<SupabaseClient> {
  const client = createClient(url, key, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({ email, password: 'voleiin123' });
  if (error) throw error;
  return client;
}

/** Arquivo de `size` bytes que começa com a assinatura do tipo. */
function fileOf(size: number, signature: number[]): Uint8Array {
  const bytes = new Uint8Array(size);
  bytes.set(signature);
  return bytes;
}

const PNG = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const JPEG = [0xff, 0xd8, 0xff];
const GIF = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61];

function path(owner: string, ext: string): string {
  return `profiles/${owner}/${crypto.randomUUID()}.${ext}`;
}

Deno.test('Fotos de perfil (RN106)', async (t) => {
  if (!key) throw new Error('Defina SUPABASE_PUBLISHABLE_KEY (supabase status).');

  const ana = await signIn('ana@voleiin.test');
  const bruno = await signIn('bruno@voleiin.test');
  const created: { client: SupabaseClient; path: string }[] = [];

  async function upload(
    client: SupabaseClient,
    target: string,
    bytes: Uint8Array,
    contentType: string,
  ) {
    const result = await client.storage.from('avatars').upload(target, bytes, {
      contentType,
      upsert: false,
    });
    if (!result.error) created.push({ client, path: target });
    return result;
  }

  try {
    await t.step('A01: Ana envia um PNG de 100 KB para a própria pasta', async () => {
      const { error } = await upload(ana, path(ANA, 'png'), fileOf(100 * 1024, PNG), 'image/png');
      assertEquals(error, null);
    });

    await t.step('A02: JPEG de 2 MB mais 1 byte é recusado pelo tamanho', async () => {
      const { error } = await upload(
        ana,
        path(ANA, 'jpg'),
        fileOf(MAX_BYTES + 1, JPEG),
        'image/jpeg',
      );
      assert(error, 'o envio deveria ser recusado');
      assertEquals(String((error as { statusCode?: string }).statusCode), '413');
    });

    await t.step('A03: JPEG de exatamente 2 MB é aceito', async () => {
      const { error } = await upload(ana, path(ANA, 'jpg'), fileOf(MAX_BYTES, JPEG), 'image/jpeg');
      assertEquals(error, null);
    });

    await t.step('A04: GIF é recusado pelo tipo', async () => {
      const { error } = await upload(ana, path(ANA, 'gif'), fileOf(1024, GIF), 'image/gif');
      assert(error, 'o envio deveria ser recusado');
      // O corpo da API traz "error": "invalid_mime_type" com HTTP 415; o
      // supabase-js expõe o 415 em statusCode.
      assertEquals(String((error as { statusCode?: string }).statusCode), '415');
    });

    await t.step('A05: Ana não envia para a pasta do Bruno', async () => {
      const { error } = await upload(ana, path(BRUNO, 'png'), fileOf(1024, PNG), 'image/png');
      assert(error, 'o envio deveria ser recusado pelo RLS');
      assertEquals(String((error as { statusCode?: string }).statusCode), '403');
    });

    await t.step('A06: Ana recebe a URL assinada da própria foto e não a do Bruno', async () => {
      const own = path(ANA, 'png');
      const other = path(BRUNO, 'png');
      assertEquals((await upload(ana, own, fileOf(1024, PNG), 'image/png')).error, null);
      assertEquals((await upload(bruno, other, fileOf(1024, PNG), 'image/png')).error, null);

      const mine = await ana.storage.from('avatars').createSignedUrl(own, 60);
      assertEquals(mine.error, null);
      assert(mine.data?.signedUrl);

      const theirs = await ana.storage.from('avatars').createSignedUrl(other, 60);
      assert(theirs.error, 'a URL da foto do Bruno deveria ser recusada');
    });
  } finally {
    // Cada um apaga o que enviou: o teste deixa o bucket como encontrou.
    for (const { client, path: target } of created) {
      await client.storage.from('avatars').remove([target]);
    }
    await ana.auth.signOut();
    await bruno.auth.signOut();
  }
});
