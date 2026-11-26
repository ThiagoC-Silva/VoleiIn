// Contas e grupo de teste para os cenários de concorrência dos jogos.
// Research R7 de specs/003-jogo-etapa-a: 27 contas só de teste (conc-00 a
// conc-26), criadas aqui se faltarem, com a chave secreta do Supabase local. Cada
// conta chama a API com um token assinado com o JWT_SECRET local, sem login por
// senha, porque o Auth local aceita só 30 logins a cada 5 minutos. A conc-00 tem
// chave Pix e é a admin do grupo "Concorrência", de que as outras são membros.
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
const secretKey = Deno.env.get('SUPABASE_SECRET_KEY');
const jwtSecret = Deno.env.get('SUPABASE_JWT_SECRET');
if (!publishableKey || !secretKey || !jwtSecret) {
  throw new Error(
    'Missing SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY or SUPABASE_JWT_SECRET ' +
      '(see supabase/functions/_tests/README.md).',
  );
}

export const ACCOUNT_COUNT = 27;
const GROUP_NAME = 'Concorrência';

export type Account = { id: string; email: string; client: SupabaseClient };

export type Call = { data: unknown; error: { message: string } | null };

export async function rpc(
  client: SupabaseClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<Call> {
  const { data, error } = await client.rpc(fn, args);
  return { data, error } as Call;
}

// O que deu certo e o código de erro do que falhou, em qualquer ordem.
export function outcomes(calls: Call[]): string[] {
  return calls.map((call) => call.error?.message ?? 'ok').sort();
}

function base64Url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/=+$/, '').replace(/\+/g, '-').replace(
    /\//g,
    '_',
  );
}

// Token no formato do Auth, assinado com a chave local (HS256), válido por 1 h.
export async function signToken(userId: string): Promise<string> {
  const encoder = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(encoder.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const payload = base64Url(
    encoder.encode(
      JSON.stringify({
        sub: userId,
        role: 'authenticated',
        aud: 'authenticated',
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(jwtSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${payload}`));
  return `${header}.${payload}.${base64Url(new Uint8Array(signature))}`;
}

function emailOf(index: number): string {
  return `conc-${String(index).padStart(2, '0')}@voleiin.test`;
}

// Cria as contas que faltam e devolve um cliente para cada uma, na ordem.
async function ensureAccounts(): Promise<Account[]> {
  const admin = createClient(url, secretKey!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const existing = new Map<string, string>();
  const { data: list, error: listError } = await admin.auth.admin.listUsers({ perPage: 1000 });
  if (listError) throw new Error(`Could not list users: ${listError.message}`);
  for (const user of list.users) {
    if (user.email) existing.set(user.email, user.id);
  }

  const accounts: Account[] = [];
  for (let i = 0; i < ACCOUNT_COUNT; i++) {
    const email = emailOf(i);
    let id = existing.get(email);
    if (!id) {
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: crypto.randomUUID(),
        email_confirm: true,
        user_metadata: { name: `Conc ${i}` },
      });
      if (error) throw new Error(`Could not create ${email}: ${error.message}`);
      id = data.user.id;
    }
    const token = await signToken(id);
    const client = createClient(url, publishableKey!, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    accounts.push({ id, email, client });
  }
  return accounts;
}

// Grupo da conc-00 com todas as contas como membros, criado na primeira vez.
async function ensureGroup(accounts: Account[]): Promise<string> {
  const owner = accounts[0];

  // A conc-00 é a recebedora dos jogos: precisa de chave Pix (RN22).
  const { error: pixError } = await owner.client
    .from('profile_private')
    .update({ pix_key_type: 'email', pix_key: owner.email })
    .eq('user_id', owner.id);
  if (pixError) throw new Error(`Could not set the Pix key: ${pixError.message}`);

  const { data: groups, error: groupsError } = await owner.client
    .from('groups')
    .select('id, invite_code')
    .eq('name', GROUP_NAME)
    .limit(1);
  if (groupsError) throw new Error(`Could not read groups: ${groupsError.message}`);

  let groupId: string;
  let inviteCode: string;
  if (groups && groups.length > 0) {
    groupId = groups[0].id;
    inviteCode = groups[0].invite_code;
  } else {
    const created = await rpc(owner.client, 'create_group', { p_name: GROUP_NAME });
    if (created.error) throw new Error(`Could not create the group: ${created.error.message}`);
    ({ group_id: groupId, invite_code: inviteCode } = created.data as {
      group_id: string;
      invite_code: string;
    });
  }

  const { data: members, error: membersError } = await owner.client
    .from('group_members')
    .select('user_id')
    .eq('group_id', groupId);
  if (membersError) throw new Error(`Could not read members: ${membersError.message}`);
  const memberIds = new Set((members ?? []).map((m) => m.user_id));

  for (const account of accounts.slice(1)) {
    if (memberIds.has(account.id)) continue;
    const request = await rpc(account.client, 'request_group_join', { p_invite_code: inviteCode });
    if (request.error) throw new Error(`${account.email} could not ask: ${request.error.message}`);
    const requestId = (request.data as { request_id: string }).request_id;
    const decision = await rpc(owner.client, 'decide_join_request', {
      p_request_id: requestId,
      p_approve: true,
    });
    if (decision.error) throw new Error(`Could not approve: ${decision.error.message}`);
  }
  return groupId;
}

export type Fixture = { accounts: Account[]; groupId: string };

let fixture: Promise<Fixture> | undefined;

// Contas e grupo, preparados uma vez por execução.
export function concurrencyFixture(): Promise<Fixture> {
  fixture ??= (async () => {
    const accounts = await ensureAccounts();
    const groupId = await ensureGroup(accounts);
    return { accounts, groupId };
  })();
  return fixture;
}

// Jogo novo da conc-00 no grupo, com as contas de `fillers` já na lista.
export async function newGame(
  { accounts, groupId }: Fixture,
  slotLimit: number,
  fillers: Account[],
): Promise<string> {
  const day = 24 * 60 * 60 * 1000;
  const now = Date.now();
  const created = await rpc(accounts[0].client, 'create_game', {
    p_group_id: groupId,
    p_location_name: 'Quadra de teste',
    p_maps_url: null,
    p_cancellation_deadline: new Date(now + day).toISOString(),
    p_starts_at: new Date(now + day + 2 * 60 * 60 * 1000).toISOString(),
    p_ends_at: new Date(now + day + 4 * 60 * 60 * 1000).toISOString(),
    p_total_cents: 9000,
    p_slot_limit: slotLimit,
  });
  if (created.error) throw new Error(`Could not create the game: ${created.error.message}`);
  const gameId = (created.data as { game_id: string }).game_id;
  for (const account of fillers) {
    const joined = await rpc(account.client, 'join_game', { p_game_id: gameId });
    if (joined.error) throw new Error(`${account.email} could not join: ${joined.error.message}`);
  }
  return gameId;
}

// Vagas ocupadas, limite e status, lidos pela admin do jogo.
export async function gameState(
  { accounts }: Fixture,
  gameId: string,
): Promise<{ occupied: number; slotLimit: number; status: string }> {
  const owner = accounts[0].client;
  const { data: game, error: gameError } = await owner
    .from('games')
    .select('slot_limit, status')
    .eq('id', gameId)
    .single();
  if (gameError) throw new Error(`Could not read the game: ${gameError.message}`);
  const { count, error: countError } = await owner
    .from('game_participants')
    .select('id', { count: 'exact', head: true })
    .eq('game_id', gameId)
    .in('status', ['active', 'left_after_start']);
  if (countError) throw new Error(`Could not count: ${countError.message}`);
  return { occupied: count ?? 0, slotLimit: game.slot_limit, status: game.status };
}

// Devolve a conta ao grupo de teste, se ela tiver saído (C16).
export async function rejoinGroup({ accounts, groupId }: Fixture, account: Account): Promise<void> {
  const owner = accounts[0].client;
  const { data: member } = await owner
    .from('group_members')
    .select('user_id')
    .eq('group_id', groupId)
    .eq('user_id', account.id)
    .maybeSingle();
  if (member) return;
  const { data: group, error } = await owner
    .from('groups')
    .select('invite_code')
    .eq('id', groupId)
    .single();
  if (error) throw new Error(`Could not read the group: ${error.message}`);
  const request = await rpc(account.client, 'request_group_join', {
    p_invite_code: group.invite_code,
  });
  if (request.error) throw new Error(`${account.email} could not ask: ${request.error.message}`);
  const decision = await rpc(owner, 'decide_join_request', {
    p_request_id: (request.data as { request_id: string }).request_id,
    p_approve: true,
  });
  if (decision.error) throw new Error(`Could not approve: ${decision.error.message}`);
}
