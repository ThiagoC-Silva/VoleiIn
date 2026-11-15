// Concorrência nos grupos (RN12).
// Cenários C13 e C15 de docs/testes-referencia.md, seção 11.5. O C14 foi
// retirado em 15/11/2026 (nota da mesma seção).
//
// Cada cenário dispara as duas chamadas juntas, por clientes separados: o
// PostgREST atende cada uma numa conexão própria do banco local (research R4 de
// specs/002-grupos). Cada repetição devolve o seed ao estado inicial pelas
// próprias funções. Recusas do Diego no Vôlei de Quinta ficam no banco local,
// sem efeito nos outros cenários, até o próximo `supabase db reset`.
//
//   SUPABASE_URL=http://127.0.0.1:54321 SUPABASE_PUBLISHABLE_KEY=<chave> \
//     deno test --allow-net --allow-env
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { assert, assertEquals } from '@std/assert';

const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
if (!key) {
  throw new Error('Missing SUPABASE_PUBLISHABLE_KEY (see docs/setup.md, section 5).');
}

const QUINTA = '00000000-0000-0000-0000-000000000101';
const BRUNO = '00000000-0000-0000-0000-00000000000b';
const DIEGO = '00000000-0000-0000-0000-00000000000d';
const PASSWORD = 'voleiin123';
const REPETITIONS = 50;

async function signIn(email: string): Promise<SupabaseClient> {
  const client = createClient(url, key!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw new Error(`Could not sign in ${email}: ${error.message}`);
  return client;
}

type Call = { data: unknown; error: { message: string } | null };

async function rpc(client: SupabaseClient, fn: string, args: Record<string, unknown>) {
  const { data, error } = await client.rpc(fn, args);
  return { data, error } as Call;
}

// O que deu certo e o código de erro do que falhou, em qualquer ordem.
function outcomes(calls: Call[]): string[] {
  return calls.map((call) => call.error?.message ?? 'ok').sort();
}

async function pendingRequestsOfDiego(diego: SupabaseClient): Promise<{ id: string }[]> {
  const { data, error } = await diego
    .from('group_join_requests')
    .select('id')
    .eq('group_id', QUINTA)
    .eq('status', 'pending');
  assertEquals(error, null);
  return data ?? [];
}

const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test('C13: pedidos simultâneos da mesma pessoa (RN12)', options, async () => {
  const ana = await signIn('ana@voleiin.test');
  const diego = await signIn('diego@voleiin.test');
  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const calls = await Promise.all([
        rpc(diego, 'request_group_join', { p_invite_code: 'VoleiQuinta1' }),
        rpc(diego, 'request_group_join', { p_invite_code: 'VoleiQuinta1' }),
      ]);
      assertEquals(outcomes(calls), ['JOIN_REQUEST_PENDING', 'ok'], `repetition ${i}`);

      const pending = await pendingRequestsOfDiego(diego);
      assertEquals(pending.length, 1, `repetition ${i}: always one pending request`);

      // Volta ao seed: Ana recusa o pedido.
      const reset = await rpc(ana, 'decide_join_request', {
        p_request_id: pending[0].id,
        p_approve: false,
      });
      assertEquals(reset.error, null);
    }
  } finally {
    await ana.auth.signOut();
    await diego.auth.signOut();
  }
});

Deno.test('C15: aprovar e recusar ao mesmo tempo', options, async () => {
  const ana = await signIn('ana@voleiin.test');
  const bruno = await signIn('bruno@voleiin.test');
  const diego = await signIn('diego@voleiin.test');

  // Bruno vira admin do Quinta durante o teste.
  const promote = await rpc(ana, 'set_group_role', {
    p_group_id: QUINTA,
    p_user_id: BRUNO,
    p_role: 'admin',
  });
  assertEquals(promote.error, null);

  try {
    for (let i = 0; i < REPETITIONS; i++) {
      const request = await rpc(diego, 'request_group_join', { p_invite_code: 'VoleiQuinta1' });
      assertEquals(request.error, null, `repetition ${i}`);
      const requestId = (request.data as { request_id: string }).request_id;

      const [approve, reject] = await Promise.all([
        rpc(ana, 'decide_join_request', { p_request_id: requestId, p_approve: true }),
        rpc(bruno, 'decide_join_request', { p_request_id: requestId, p_approve: false }),
      ]);
      assertEquals(outcomes([approve, reject]), ['REQUEST_NOT_PENDING', 'ok'], `repetition ${i}`);

      const { data: members, error } = await ana
        .from('group_members')
        .select('user_id')
        .eq('group_id', QUINTA)
        .eq('user_id', DIEGO);
      assertEquals(error, null);
      const approvalWon = approve.error === null;
      assertEquals(
        members?.length === 1,
        approvalWon,
        `repetition ${i}: Diego is a member if, and only if, the approval won`,
      );

      // Volta ao seed: se entrou, Diego sai.
      if (approvalWon) {
        const leave = await rpc(diego, 'leave_group', { p_group_id: QUINTA });
        assertEquals(leave.error, null);
      }
      assert((await pendingRequestsOfDiego(diego)).length === 0);
    }
  } finally {
    await rpc(ana, 'set_group_role', { p_group_id: QUINTA, p_user_id: BRUNO, p_role: 'member' });
    await ana.auth.signOut();
    await bruno.auth.signOut();
    await diego.auth.signOut();
  }
});
