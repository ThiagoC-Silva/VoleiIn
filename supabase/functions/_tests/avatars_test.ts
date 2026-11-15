// Fotos no bucket `avatars` (RN106, RN107).
// Cenários A01 a A06 (fotos de perfil, seção 10.3) e A07 a A13 (fotos do grupo e
// de outras pessoas, seção 11.3) de docs/testes-referencia.md.
//
// Roda contra a API do Storage local, com as contas e os grupos do seed logados
// por e-mail e senha (docs/setup.md, seção 8): o Vôlei de Quinta, com Ana admin
// e Bruno e Carla membros, e o Vôlei de Domingo, só com o Bruno admin e a
// solicitação pendente do Diego.
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
const DIEGO = '00000000-0000-0000-0000-00000000000d';
const QUINTA = '00000000-0000-0000-0000-000000000101';
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

function groupPath(groupId: string): string {
  return `groups/${groupId}/${crypto.randomUUID()}.png`;
}

function statusOf(error: unknown): string {
  return String((error as { statusCode?: string } | null)?.statusCode);
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
  // O Diego não compartilha contexto com a Ana (RN107). Até a fatia 2, o A06
  // usava o Bruno, que o seed da fatia 3 pôs no grupo da Ana (decisão de
  // 15/11/2026, docs/testes-referencia.md, 10.3).
  const diego = await signIn('diego@voleiin.test');
  const uploadedByAna: string[] = [];
  const uploadedByDiego: string[] = [];

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
      const diegoFile = path(DIEGO, 'png');
      const { error: diegoUploadError } = await upload(diego, diegoFile, 1024, 'image/png');
      assertEquals(diegoUploadError, null);
      uploadedByDiego.push(diegoFile);

      const own = await ana.storage.from(BUCKET).createSignedUrl(uploadedByAna[0], 60);
      assertEquals(own.error, null);
      assert(own.data?.signedUrl, 'Ana should get the signed URL of her own file');

      const other = await ana.storage.from(BUCKET).createSignedUrl(diegoFile, 60);
      assert(other.error, 'the signed URL of the file of Diego should be refused');
      assertEquals(other.data, null);
    });
  } finally {
    // Deixa o bucket como encontrou.
    if (uploadedByAna.length > 0) await ana.storage.from(BUCKET).remove(uploadedByAna);
    if (uploadedByDiego.length > 0) await diego.storage.from(BUCKET).remove(uploadedByDiego);
    await ana.auth.signOut();
    await diego.auth.signOut();
  }
});

Deno.test('fotos do grupo e de outras pessoas (RN106, RN107)', options, async (t) => {
  const ana = await signIn('ana@voleiin.test');
  const bruno = await signIn('bruno@voleiin.test');
  const diego = await signIn('diego@voleiin.test');
  const uploadedByAna: string[] = [];
  const uploadedByDiego: string[] = [];
  let groupPhoto = '';

  try {
    await t.step('A07: Ana, admin, envia a foto do Quinta', async () => {
      groupPhoto = groupPath(QUINTA);
      const { error } = await upload(ana, groupPhoto, 1024, 'image/png');
      assertEquals(error, null);
      uploadedByAna.push(groupPhoto);
    });

    await t.step('A08: Bruno (membro) e Diego (sem grupo) não enviam', async () => {
      for (const client of [bruno, diego]) {
        const { data, error } = await upload(client, groupPath(QUINTA), 1024, 'image/png');
        assertEquals(data, null);
        assertEquals(statusOf(error), '403');
      }
    });

    await t.step('A09: Bruno recebe a URL assinada da foto do grupo; Diego não', async () => {
      const own = await bruno.storage.from(BUCKET).createSignedUrl(groupPhoto, 60);
      assertEquals(own.error, null);
      assert(own.data?.signedUrl, 'Bruno should get the signed URL');

      const other = await diego.storage.from(BUCKET).createSignedUrl(groupPhoto, 60);
      assert(other.error, 'Diego should be refused');
      assertEquals(other.data, null);
    });

    await t.step('A10: foto de perfil da Ana: Bruno recebe (contexto), Diego não', async () => {
      const anaPhoto = path(ANA, 'png');
      const { error } = await upload(ana, anaPhoto, 1024, 'image/png');
      assertEquals(error, null);
      uploadedByAna.push(anaPhoto);

      const withContext = await bruno.storage.from(BUCKET).createSignedUrl(anaPhoto, 60);
      assertEquals(withContext.error, null);
      assert(withContext.data?.signedUrl, 'Bruno should get the signed URL');

      const withoutContext = await diego.storage.from(BUCKET).createSignedUrl(anaPhoto, 60);
      assert(withoutContext.error, 'Diego should be refused (RN107)');
      assertEquals(withoutContext.data, null);
    });

    await t.step('A11: foto do Diego: Bruno recebe (pedido no Domingo), Ana não', async () => {
      const diegoPhoto = path(DIEGO, 'png');
      const { error } = await upload(diego, diegoPhoto, 1024, 'image/png');
      assertEquals(error, null);
      uploadedByDiego.push(diegoPhoto);

      const admin = await bruno.storage.from(BUCKET).createSignedUrl(diegoPhoto, 60);
      assertEquals(admin.error, null);
      assert(admin.data?.signedUrl, 'Bruno, admin of Domingo, should get the signed URL');

      const other = await ana.storage.from(BUCKET).createSignedUrl(diegoPhoto, 60);
      assert(other.error, 'Ana should be refused');
      assertEquals(other.data, null);
    });

    await t.step('A12: Bruno não apaga a foto do grupo; Ana apaga', async () => {
      const name = groupPhoto.split('/').pop()!;
      const exists = async () => {
        const { data, error } = await ana.storage.from(BUCKET).list(`groups/${QUINTA}`, {
          search: name,
        });
        assertEquals(error, null);
        return (data ?? []).some((file) => file.name === name);
      };

      await bruno.storage.from(BUCKET).remove([groupPhoto]);
      assert(await exists(), 'the delete by Bruno should not remove the file');

      const { error } = await ana.storage.from(BUCKET).remove([groupPhoto]);
      assertEquals(error, null);
      assertEquals(await exists(), false);
      uploadedByAna.splice(uploadedByAna.indexOf(groupPhoto), 1);
    });

    await t.step('A13: pasta que não é UUID é recusada, sem erro no banco', async () => {
      const { data, error } = await upload(ana, 'groups/nao-e-uuid/x.png', 1024, 'image/png');
      assertEquals(data, null);
      assertEquals(statusOf(error), '403');
    });
  } finally {
    if (uploadedByAna.length > 0) await ana.storage.from(BUCKET).remove(uploadedByAna);
    if (uploadedByDiego.length > 0) await diego.storage.from(BUCKET).remove(uploadedByDiego);
    await ana.auth.signOut();
    await bruno.auth.signOut();
    await diego.auth.signOut();
  }
});
