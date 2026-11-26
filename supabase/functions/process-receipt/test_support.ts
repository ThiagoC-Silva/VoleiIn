// Apoio dos testes da process-receipt (research R7 e R10 de
// specs/010-pagamentos-etapa-b): o dublê da Claude API, as contas rcpt-*, um
// jogo concluído novo por cenário na base da seção 7 do docs/comprovantes-ia.md
// e a chamada ao handler.
//
//   SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY e
//   SUPABASE_JWT_SECRET do Supabase local (supabase/functions/_tests/README.md);
//   SUPABASE_DB_URL opcional (padrão: o banco local).
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import postgres from 'postgres';
import { signToken } from '../_tests/concurrency/support.ts';

export const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'http://127.0.0.1:54321';
export const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? '';
export const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
const dbUrl = Deno.env.get('SUPABASE_DB_URL') ??
  'postgresql://postgres:postgres@127.0.0.1:54322/postgres';
if (!publishableKey || !secretKey) {
  throw new Error(
    'Missing SUPABASE_PUBLISHABLE_KEY or SUPABASE_SECRET_KEY (see supabase/functions/_tests/README.md).',
  );
}

// Dublê da Claude API ---------------------------------------------------------

export type MockReply =
  | { status: number; body: unknown }
  | { hang: true };

export type ClaudeMock = {
  url: string;
  // Pedidos recebidos em /v1/messages, na ordem.
  messages: Record<string, unknown>[];
  // Pedidos recebidos em /v1/messages/count_tokens.
  counts: Record<string, unknown>[];
  // Próximas respostas de /v1/messages; sem nenhuma, responde 500.
  replies: MockReply[];
  // Resposta de /v1/messages/count_tokens.
  inputTokens: number;
  reset(): void;
  close(): Promise<void>;
};

// Uma resposta da API com o JSON da leitura, como a do modelo.
export function messageReply(
  reading: unknown,
  options: { stopReason?: string; thinkingFirst?: boolean } = {},
): MockReply {
  const content: unknown[] = [];
  if (options.thinkingFirst) {
    content.push({ type: 'thinking', thinking: '', signature: 'teste' });
  }
  content.push({ type: 'text', text: JSON.stringify(reading) });
  return {
    status: 200,
    body: {
      id: 'msg_teste',
      type: 'message',
      role: 'assistant',
      model: 'modelo-teste',
      content,
      stop_reason: options.stopReason ?? 'end_turn',
      stop_sequence: null,
      usage: { input_tokens: 4500, output_tokens: 300 },
    },
  };
}

export function errorReply(status: number): MockReply {
  return {
    status,
    body: { type: 'error', error: { type: 'api_error', message: `simulado ${status}` } },
  };
}

export function startClaudeMock(): ClaudeMock {
  const pending: (() => void)[] = [];
  const mock: ClaudeMock = {
    url: '',
    messages: [],
    counts: [],
    replies: [],
    inputTokens: 3000,
    reset() {
      mock.messages.length = 0;
      mock.counts.length = 0;
      mock.replies.length = 0;
      mock.inputTokens = 3000;
    },
    close: async () => {},
  };
  const server = Deno.serve({ port: 0, hostname: '127.0.0.1', onListen() {} }, async (request) => {
    const path = new URL(request.url).pathname;
    const body = await request.json();
    if (path === '/v1/messages/count_tokens') {
      mock.counts.push(body);
      return Response.json({ input_tokens: mock.inputTokens });
    }
    mock.messages.push(body);
    const reply = mock.replies.shift() ?? errorReply(500);
    if ('hang' in reply) {
      // Não responde até o teste acabar ou quem chamou desistir.
      await new Promise<void>((resolve) => {
        pending.push(resolve);
        request.signal.addEventListener('abort', () => resolve());
        setTimeout(resolve, 40_000);
      });
      return new Response(null, { status: 504 });
    }
    return Response.json(reply.body, {
      status: reply.status,
      headers: reply.status === 429 ? { 'retry-after': '0' } : {},
    });
  });
  mock.url = `http://127.0.0.1:${server.addr.port}`;
  mock.close = async () => {
    pending.forEach((resolve) => resolve());
    await server.shutdown();
  };
  return mock;
}

// Contas e jogo ---------------------------------------------------------------

export type Person = { id: string; email: string; token: string };

export type World = {
  ana: Person;
  fabio: Person;
  bruno: Person;
  edu: Person;
  diego: Person;
  gone: Person;
  service: SupabaseClient;
  sql: postgres.Sql;
};

const PEOPLE: [keyof Omit<World, 'service' | 'sql'>, string][] = [
  ['ana', 'Ana Souza Lima'],
  ['fabio', 'Fábio Alves Pereira'],
  ['bruno', 'Bruno Costa'],
  ['edu', 'Edu Ramos'],
  ['diego', 'Diego Nunes'],
  ['gone', 'Conta Excluída'],
];

let world: Promise<World> | undefined;

// As contas rcpt-* (criadas se faltarem), com a Ana Souza Lima e a chave CPF
// 529.982.247-25 da base, e a conta "gone" marcada como excluída (PR02).
export function receiptWorld(): Promise<World> {
  world ??= (async () => {
    const service = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const sql = postgres(dbUrl, { max: 4, onnotice: () => {} });
    const { data: list, error } = await service.auth.admin.listUsers({ perPage: 1000 });
    if (error) throw new Error(`Could not list users: ${error.message}`);
    const existing = new Map(list.users.map((u) => [u.email, u.id]));

    const people: Partial<World> = { service, sql };
    for (const [key, name] of PEOPLE) {
      const email = `rcpt-${key}@voleiin.test`;
      let id = existing.get(email);
      if (!id) {
        const created = await service.auth.admin.createUser({
          email,
          password: crypto.randomUUID(),
          email_confirm: true,
          user_metadata: { name },
        });
        if (created.error) throw new Error(`Could not create ${email}: ${created.error.message}`);
        id = created.data.user.id;
      }
      await sql`update public.profiles set name = ${name}, deleted_at = null where id = ${id}`;
      (people as Record<string, Person>)[key] = { id, email, token: await signToken(id) };
    }
    const w = people as World;
    await sql`
      update public.profile_private set pix_key_type = 'cpf', pix_key = '52998224725'
      where user_id = ${w.ana.id}`;
    await sql`
      update public.profile_private set pix_key_type = 'email', pix_key = 'bruno.costa@exemplo.com'
      where user_id = ${w.bruno.id}`;
    await sql`update public.profiles set deleted_at = now() where id = ${w.gone.id}`;
    return w;
  })();
  return world;
}

// Fecha a conexão com o banco, no fim de cada arquivo de teste.
export async function closeWorld(): Promise<void> {
  if (!world) return;
  const w = await world;
  world = undefined;
  await w.sql.end();
}

// Libera os IDs de transação dos exemplos: os comprovantes ainda ativos das
// contas rcpt-* viram recusados (research R10).
export async function resetReceipts(w: World): Promise<void> {
  const payers = [w.fabio.id, w.bruno.id, w.ana.id, w.edu.id];
  await w.sql`
    update public.receipts
    set status = 'rejected', rejection_reason = 'receiver_rejected',
        receiver_note = 'Limpeza dos testes.', decided_at = coalesce(decided_at, now())
    where payer_id = any(${payers}::uuid[]) and status <> 'rejected'`;
}

function inviteCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from(crypto.getRandomValues(new Uint8Array(12)), (b) => chars[b % 62]).join('');
}

export type Game = { gameId: string; fabioCharge: string; brunoCharge: string };

// Jogo avulso concluído da base: início em 19/11/2026 às 20:00 (Fortaleza),
// Ana recebedora e admin, Edu também admin, Fábio e Bruno com share Pendente de
// 2.084 devido à Ana.
export async function newGame(w: World): Promise<Game> {
  return await w.sql.begin(async (tx) => {
    const [game] = await tx`
      insert into public.games (
        created_by, location_name, cancellation_deadline, starts_at, ends_at, total_cents,
        slot_limit, receiver_id, invite_code, status, share_cents, completed_at,
        completion_mode, completed_by
      ) values (
        ${w.ana.id}, 'Quadra de teste', '2026-11-19 18:00-03', '2026-11-19 20:00-03',
        '2026-11-19 22:00-03', 6252, 3, ${w.ana.id}, ${inviteCode()}, 'completed', 2084,
        '2026-11-19 22:10-03', 'manual', ${w.ana.id}
      ) returning id`;
    await tx`
      insert into public.game_admins (game_id, user_id, added_by)
      values (${game.id}, ${w.ana.id}, null), (${game.id}, ${w.edu.id}, ${w.ana.id})`;
    const participants = await tx`
      insert into public.game_participants (game_id, user_id, joined_at)
      select ${game.id}, u, '2026-11-18 12:00-03'
      from unnest(${[w.ana.id, w.fabio.id, w.bruno.id]}::uuid[]) u
      returning id, user_id`;
    const charges: Record<string, string> = {};
    for (const p of participants) {
      if (p.user_id === w.ana.id) continue;
      const [charge] = await tx`
        insert into public.charges (game_id, participant_id, payer_id, receiver_id, kind, amount_cents)
        values (${game.id}, ${p.id}, ${p.user_id}, ${w.ana.id}, 'share', 2084)
        returning id`;
      await tx`
        insert into public.charge_events (charge_id, from_status, to_status, actor_id)
        values (${charge.id}, null, 'pending', ${w.ana.id})`;
      charges[p.user_id] = charge.id;
    }
    return { gameId: game.id, fabioCharge: charges[w.fabio.id], brunoCharge: charges[w.bruno.id] };
  });
}

// Envia o arquivo como o pagador faria e devolve o caminho.
export async function upload(
  w: World,
  chargeId: string,
  bytes: Uint8Array,
  mimeType: string,
  ext: string,
): Promise<string> {
  const path = `${chargeId}/${crypto.randomUUID()}.${ext}`;
  const { error } = await w.service.storage.from('receipts').upload(path, bytes, {
    contentType: mimeType,
  });
  if (error) throw new Error(`Could not upload ${path}: ${error.message}`);
  return path;
}

// Chamada ao handler ----------------------------------------------------------

export type Handler = (request: Request) => Promise<Response>;
export type Result = { status: number; body: Record<string, unknown> };

export async function invoke(
  handler: Handler,
  token: string | null,
  body: unknown,
): Promise<Result> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await handler(
    new Request('http://localhost/functions/v1/process-receipt', {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    }),
  );
  return { status: response.status, body: await response.json() };
}

export function errorCode(result: Result): unknown {
  return (result.body.error as { code?: string } | undefined)?.code;
}

// Exemplos do conjunto fixo -----------------------------------------------------

export type Fixture = {
  id: string;
  title: string;
  file: string;
  mime_type: string;
  reading: Record<string, string | null> | null;
  expected: { result: string; error_code?: string; validation?: Record<string, unknown> };
  count_tokens?: number;
  approved_elsewhere?: boolean;
};

const fixturesDir = new URL('./fixtures/', import.meta.url);

export async function loadFixtures(): Promise<Fixture[]> {
  const out: Fixture[] = [];
  for await (const entry of Deno.readDir(fixturesDir)) {
    if (entry.name.endsWith('.json')) {
      out.push(JSON.parse(await Deno.readTextFile(new URL(entry.name, fixturesDir))));
    }
  }
  return out.sort((a, b) => a.id.localeCompare(b.id));
}

export function fixtureBytes(fixture: Fixture): Promise<Uint8Array> {
  return Deno.readFile(new URL(fixture.file, fixturesDir));
}

export type FixtureRun = {
  fixture: Fixture;
  result: Result;
  receipt: Record<string, unknown> | null;
  ms: number;
};

// Roda um exemplo de ponta a ponta: um jogo novo, o arquivo no bucket e o
// handler, como o Fábio. No CF22, um comprovante aprovado do Bruno com o mesmo
// ID vem antes (research R10).
export async function runFixture(
  w: World,
  handler: Handler,
  fixture: Fixture,
): Promise<FixtureRun> {
  await resetReceipts(w);
  const game = await newGame(w);
  if (fixture.approved_elsewhere) {
    const reading = fixture.reading!;
    const { error } = await w.service.rpc('record_receipt', {
      p_charge_id: game.brunoCharge,
      p_payer_id: w.bruno.id,
      p_storage_path: `${game.brunoCharge}/${crypto.randomUUID()}.png`,
      p_mime_type: 'image/png',
      p_size_bytes: 1000,
      p_reading: {
        outcome: 'read',
        amount_cents: 2084,
        paid_at: reading.paid_at,
        recipient_name: reading.recipient_name,
        recipient_key: null,
        transaction_id: reading.transaction_id,
        raw: {},
      },
    });
    if (error) throw new Error(`Could not record the other receipt: ${error.message}`);
  }
  const ext = fixture.file.split('.').pop()!;
  const path = await upload(
    w,
    game.fabioCharge,
    await fixtureBytes(fixture),
    fixture.mime_type,
    ext,
  );
  const started = performance.now();
  const result = await invoke(handler, w.fabio.token, {
    charge_id: game.fabioCharge,
    storage_path: path,
  });
  const ms = performance.now() - started;
  const receiptId = result.body.receipt_id as string | undefined;
  const [receipt] = receiptId
    ? await w.sql`select * from public.receipts where id = ${receiptId}`
    : [null];
  return { fixture, result, receipt, ms };
}

// Confere o resultado esperado da seção 7. Devolve as diferenças.
export function checkExpected(run: FixtureRun): string[] {
  const problems: string[] = [];
  const { expected } = run.fixture;
  if (run.result.status !== 200) {
    return [`HTTP ${run.result.status} ${JSON.stringify(run.result.body)}`];
  }
  if (run.result.body.result !== expected.result) {
    problems.push(`result ${run.result.body.result}, esperado ${expected.result}`);
  }
  if ((run.result.body.error_code ?? null) !== (expected.error_code ?? null)) {
    problems.push(`error_code ${run.result.body.error_code}, esperado ${expected.error_code}`);
  }
  const validation = (run.receipt?.validation ?? {}) as Record<string, unknown>;
  for (const [key, value] of Object.entries(expected.validation ?? {})) {
    if ((validation[key] ?? null) !== value) {
      problems.push(`validation.${key} ${validation[key]}, esperado ${value}`);
    }
  }
  return problems;
}
