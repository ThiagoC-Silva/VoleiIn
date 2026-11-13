// Fotos de perfil no bucket `avatars` (RN106).
// Cenários A01 a A06 de docs/testes-referencia.md, seção 10.3.
//
// Roda contra a API do Storage local, com a Ana e o Bruno do seed logados por
// e-mail e senha (docs/setup.md, seção 8):
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave> \
//     deno test --allow-net --allow-env
//
// O Storage confere o tipo declarado no envio e o tamanho. O app garante o tipo
// real ao redimensionar a foto.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from '@std/assert';

const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
if (!key) {
  throw new Error('Missing SUPABASE_PUBLISHABLE_KEY (see docs/setup.md, section 5).');
}

const ANA = '00000000-0000-0000-0000-00000000000a';
const BRUNO = '00000000-0000-0000-0000-00000000000b';
const PASSWORD = 'voleiin123';
const BUCKET = 'avatars';
const TWO_MB = 2_097_152;

async function signIn(email: string): Promise<SupabaseClient> {
  const client = createClient(url, key!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw new Error(`Could not sign in ${email}: ${error.message}`);
  return client;
}

function path(userId: string, ext: string): string {
  return `profiles/${userId}/${crypto.randomUUID()}.${ext}`;
}

function upload(client: SupabaseClient, name: string, size: number, contentType: string) {
  return client.storage.from(BUCKET).upload(name, new Uint8Array(size), {
    contentType,
    upsert: false,
  });
}

// O supabase-js mantém conexões abertas entre as chamadas: os sanitizadores do
// Deno acusariam vazamento num teste que só fala com a API.
const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test('fotos de perfil no bucket avatars (RN106)', options, async (t) => {
  const ana = await signIn('ana@voleiin.test');
  const bruno = await signIn('bruno@voleiin.test');
  const uploadedByAna: string[] = [];
  const uploadedByBruno: string[] = [];

  try {
    await t.step('A01: PNG de 100 KB na própria pasta é aceito', async () => {
      const name = path(ANA, 'png');
      const { error } = await upload(ana, name, 100 * 1024, 'image/png');
      assertEquals(error, null);
      uploadedByAna.push(name);
    });

    await t.step('A02: JPEG de 2 MB mais 1 byte é recusado pelo tamanho', async () => {
      const name = path(ANA, 'jpg');
      const { data, error } = await upload(ana, name, TWO_MB + 1, 'image/jpeg');
      assertEquals(data, null);
      assert(error, 'the upload should be refused');
      assertEquals(String((error as { statusCode?: string }).statusCode), '413');
    });

    await t.step('A03: JPEG de exatamente 2 MB é aceito', async () => {
      const name = path(ANA, 'jpg');
      const { error } = await upload(ana, name, TWO_MB, 'image/jpeg');
      assertEquals(error, null);
      uploadedByAna.push(name);
    });

    await t.step('A04: GIF é recusado pelo tipo', async () => {
      const name = path(ANA, 'gif');
      const { data, error } = await upload(ana, name, 1024, 'image/gif');
      assertEquals(data, null);
      assert(error, 'the upload should be refused');
      assertEquals(String((error as { statusCode?: string }).statusCode), '415');
    });

    await t.step('A05: PNG na pasta do Bruno é recusado pelo RLS', async () => {
      const name = path(BRUNO, 'png');
      const { data, error } = await upload(ana, name, 1024, 'image/png');
      assertEquals(data, null);
      assert(error, 'the upload should be refused');
      assertEquals(String((error as { statusCode?: string }).statusCode), '403');
    });

    await t.step('A06: Ana recebe a URL assinada só do próprio arquivo', async () => {
      const brunoFile = path(BRUNO, 'png');
      const { error: brunoUploadError } = await upload(bruno, brunoFile, 1024, 'image/png');
      assertEquals(brunoUploadError, null);
      uploadedByBruno.push(brunoFile);

      const own = await ana.storage.from(BUCKET).createSignedUrl(uploadedByAna[0], 60);
      assertEquals(own.error, null);
      assert(own.data?.signedUrl, 'Ana should get the signed URL of her own file');

      const other = await ana.storage.from(BUCKET).createSignedUrl(brunoFile, 60);
      assert(other.error, 'the signed URL of the file of Bruno should be refused');
      assertEquals(other.data, null);
    });
  } finally {
    // Deixa o bucket como encontrou.
    if (uploadedByAna.length > 0) await ana.storage.from(BUCKET).remove(uploadedByAna);
    if (uploadedByBruno.length > 0) await bruno.storage.from(BUCKET).remove(uploadedByBruno);
    await ana.auth.signOut();
    await bruno.auth.signOut();
  }
});
