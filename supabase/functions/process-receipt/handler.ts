// process-receipt (docs/contratos-api.md, seção 8; docs/comprovantes-ia.md).
// Lê o comprovante enviado ao bucket, chama a Claude API, normaliza o que veio
// dela e grava pela record_receipt, que confere a RN88 no SQL (ADR 0019).
// Ordem das validações: research R8 de specs/010-pagamentos-etapa-b.
//
// O handler recebe os clientes prontos (research R7): o index.ts os monta pelo
// ambiente, e os testes, com o dublê da Claude API.
import Anthropic from '@anthropic-ai/sdk';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { encodeBase64 } from '@std/encoding/base64';
import { bearerToken, errorResponse, jsonResponse, log } from '../_shared/http.ts';
import { type ModelReading, type NormalizedReading, normalizeReading } from './normalize.ts';
import { OUTPUT_SCHEMA, PROMPT, PROMPT_VERSION, USER_TEXT } from './prompt.ts';

export type Deps = {
  supabaseUrl: string;
  anonKey: string;
  serviceKey: string;
  // Nulo sem ANTHROPIC_API_KEY: a leitura falha e o comprovante vai para análise.
  anthropic: Anthropic | null;
  model: string | null;
};

// comprovantes-ia.md, seções 2 e 6.
const API_BUDGET_MS = 25_000;
const RETRY_MIN_MS = 12_000;
const PDF_TOKEN_LIMIT = 20_000;
const MAX_BYTES = 10 * 1024 * 1024;
const MAX_TOKENS = 4096;
const MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'];
const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
const UUID_RE = new RegExp(`^${UUID}$`);
const PATH_RE = new RegExp(`^(${UUID})/${UUID}\\.(jpg|jpeg|png|webp|heic|pdf)$`);
const HEIC_BRANDS = ['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'];

// HTTP de cada código (contratos-api.md, seção 2).
const HTTP_STATUS: Record<string, number> = {
  NOT_AUTHENTICATED: 401,
  NOT_CHARGE_PAYER: 403,
  NOT_FOUND: 404,
  CHARGE_NOT_PENDING: 409,
  INVALID_INPUT: 422,
  RECEIPT_FILE_NOT_FOUND: 422,
  RECEIPT_TYPE_INVALID: 422,
  RECEIPT_TOO_LARGE: 422,
};

type Outcome = 'read' | 'failed' | 'skipped_limit' | 'skipped_file';

type Reading = {
  outcome: Outcome;
  fields?: NormalizedReading;
  raw?: Record<string, unknown>;
  usage?: { input_tokens?: number; output_tokens?: number };
  calls: number;
};

type ChargeRow = { id: string; payer_id: string; status: string; auto_reads_used: number };

class HttpError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

// O tipo pelos primeiros bytes (research R8).
export function sniffType(bytes: Uint8Array): string | null {
  const ascii = (start: number, end: number) =>
    String.fromCharCode(...bytes.subarray(start, Math.min(end, bytes.length)));
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((b, i) => bytes[i] === b)
  ) return 'image/png';
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return 'image/webp';
  if (ascii(0, 5) === '%PDF-') return 'application/pdf';
  if (ascii(4, 8) === 'ftyp' && HEIC_BRANDS.includes(ascii(8, 12))) return 'image/heic';
  return null;
}

// O JSON do modelo dentro do schema: os seis campos, texto ou nulo, nada a mais.
function parseReading(text: string): ModelReading | null {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return null;
  }
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const keys = OUTPUT_SCHEMA.required as readonly string[];
  if (Object.keys(record).length !== keys.length || !keys.every((k) => k in record)) return null;
  if (!keys.every((k) => record[k] === null || typeof record[k] === 'string')) return null;
  const status = record.payment_status;
  if (status !== null && !['completed', 'scheduled', 'other'].includes(status as string)) {
    return null;
  }
  return record as ModelReading;
}

function retryable(error: unknown): boolean {
  if (error instanceof Anthropic.APIUserAbortError) return false;
  if (error instanceof Anthropic.APIConnectionError) return true;
  return error instanceof Anthropic.APIError &&
    (error.status === 429 || (error.status ?? 0) >= 500);
}

// A leitura pela Claude API, com o prazo de 25 s para a contagem, a chamada e a
// repetição juntas (research R9).
async function readWithClaude(
  anthropic: Anthropic,
  model: string,
  mimeType: string,
  bytes: Uint8Array,
): Promise<Reading> {
  const deadline = Date.now() + API_BUDGET_MS;
  const remaining = () => deadline - Date.now();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), API_BUDGET_MS);
  const requestOptions = () => ({
    signal: controller.signal,
    maxRetries: 0,
    timeout: Math.max(remaining(), 1),
  });
  const data = encodeBase64(bytes);
  const file = mimeType === 'application/pdf'
    ? {
      type: 'document' as const,
      source: { type: 'base64' as const, media_type: 'application/pdf' as const, data },
    }
    : {
      type: 'image' as const,
      source: {
        type: 'base64' as const,
        media_type: mimeType as 'image/jpeg' | 'image/png' | 'image/webp',
        data,
      },
    };
  const messages = [{
    role: 'user' as const,
    content: [file, { type: 'text' as const, text: USER_TEXT }],
  }];
  let calls = 0;
  try {
    if (mimeType === 'application/pdf') {
      const count = await anthropic.messages.countTokens(
        { model, system: PROMPT, messages },
        requestOptions(),
      );
      if (count.input_tokens > PDF_TOKEN_LIMIT) {
        return { outcome: 'skipped_file', raw: { input_tokens: count.input_tokens }, calls };
      }
    }
    for (;;) {
      calls++;
      try {
        const response = await anthropic.messages.create(
          {
            model,
            max_tokens: MAX_TOKENS,
            system: PROMPT,
            messages,
            output_config: {
              effort: 'low',
              format: {
                type: 'json_schema',
                schema: OUTPUT_SCHEMA as unknown as Record<string, unknown>,
              },
            },
          },
          requestOptions(),
        );
        const usage = {
          input_tokens: response.usage?.input_tokens,
          output_tokens: response.usage?.output_tokens,
        };
        const failed = (reason: string): Reading => ({
          outcome: 'failed',
          raw: {
            error: reason,
            model: response.model,
            prompt_version: PROMPT_VERSION,
            usage: response.usage,
          },
          usage,
          calls,
        });
        if (response.stop_reason === 'refusal' || response.stop_reason === 'max_tokens') {
          return failed(response.stop_reason);
        }
        const text = response.content.find((block) => block.type === 'text');
        const reading = text && text.type === 'text' ? parseReading(text.text) : null;
        if (!reading) return failed('schema');
        return {
          outcome: 'read',
          fields: normalizeReading(reading),
          raw: {
            response: reading,
            model: response.model,
            prompt_version: PROMPT_VERSION,
            usage: response.usage,
          },
          usage,
          calls,
        };
      } catch (error) {
        if (calls === 1 && retryable(error) && remaining() >= RETRY_MIN_MS) continue;
        throw error;
      }
    }
  } catch (error) {
    const status = error instanceof Anthropic.APIError ? error.status : undefined;
    return {
      outcome: 'failed',
      raw: { error: error instanceof Error ? error.name : 'unknown', status: status ?? null },
      calls,
    };
  } finally {
    clearTimeout(timer);
  }
}

export function createHandler(deps: Deps): (request: Request) => Promise<Response> {
  const service: SupabaseClient = createClient(deps.supabaseUrl, deps.serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return async function handler(request: Request): Promise<Response> {
    const started = Date.now();
    let chargeId: string | undefined;
    try {
      if (request.method !== 'POST') throw new HttpError('INVALID_INPUT');

      // 1. Quem chama: conta que existe e não foi excluída.
      const token = bearerToken(request);
      const { data: auth, error: authError } = token
        ? await service.auth.getUser(token)
        : { data: { user: null }, error: null };
      const uid = auth.user?.id;
      if (authError || !uid) throw new HttpError('NOT_AUTHENTICATED');
      const { data: profile } = await service
        .from('profiles')
        .select('deleted_at')
        .eq('id', uid)
        .maybeSingle();
      if (!profile || profile.deleted_at !== null) throw new HttpError('NOT_AUTHENTICATED');

      let body: { charge_id?: unknown; storage_path?: unknown };
      try {
        body = await request.json();
      } catch {
        throw new HttpError('INVALID_INPUT');
      }
      if (
        typeof body?.charge_id !== 'string' || !UUID_RE.test(body.charge_id) ||
        typeof body.storage_path !== 'string'
      ) {
        throw new HttpError('INVALID_INPUT');
      }
      chargeId = body.charge_id;
      const path = body.storage_path;

      // 2. O valor, pelo RLS de quem chama (research R1).
      const user = createClient(deps.supabaseUrl, deps.anonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const { data: charge, error: chargeError } = await user
        .from('charges')
        .select('id, payer_id, status, auto_reads_used')
        .eq('id', chargeId)
        .maybeSingle<ChargeRow>();
      if (chargeError) throw chargeError;
      if (!charge) throw new HttpError('NOT_FOUND');
      if (charge.payer_id !== uid) throw new HttpError('NOT_CHARGE_PAYER');
      if (charge.status !== 'pending') throw new HttpError('CHARGE_NOT_PENDING');

      // 3. O caminho do próprio valor.
      const match = path.match(PATH_RE);
      if (!match || match[1] !== chargeId) throw new HttpError('INVALID_INPUT');
      const { data: used } = await service
        .from('receipts')
        .select('id')
        .eq('storage_path', path)
        .maybeSingle();
      if (used) throw new HttpError('INVALID_INPUT');

      // 4. O arquivo: existe, tamanho e tipo pelos primeiros bytes (RN87).
      const { data: blob, error: downloadError } = await service.storage
        .from('receipts')
        .download(path);
      if (downloadError || !blob) throw new HttpError('RECEIPT_FILE_NOT_FOUND');
      if (blob.size > MAX_BYTES) throw new HttpError('RECEIPT_TOO_LARGE');
      const mimeType = blob.type.split(';')[0].trim();
      const bytes = new Uint8Array(await blob.arrayBuffer());
      if (!MIME_TYPES.includes(mimeType) || sniffType(bytes) !== mimeType) {
        throw new HttpError('RECEIPT_TYPE_INVALID');
      }

      // 5. A leitura, ou o motivo de não ler (RN86).
      let reading: Reading;
      if (charge.auto_reads_used >= 3) {
        reading = { outcome: 'skipped_limit', calls: 0 };
      } else if (mimeType === 'image/heic') {
        reading = { outcome: 'skipped_file', calls: 0 };
      } else if (!deps.anthropic || !deps.model) {
        log('process_receipt_config', { result: 'missing_anthropic_key_or_model' });
        reading = { outcome: 'failed', raw: { error: 'not_configured' }, calls: 0 };
      } else {
        reading = await readWithClaude(deps.anthropic, deps.model, mimeType, bytes);
      }

      // 6. A gravação, com a conferência da RN88 (record_receipt).
      const { data: recorded, error: recordError } = await service.rpc('record_receipt', {
        p_charge_id: chargeId,
        p_payer_id: uid,
        p_storage_path: path,
        p_mime_type: mimeType,
        p_size_bytes: bytes.length,
        p_reading: {
          outcome: reading.outcome,
          ...(reading.fields ?? {}),
          raw: reading.raw ?? null,
        },
      });
      if (recordError) {
        if (recordError.message in HTTP_STATUS) throw new HttpError(recordError.message);
        throw recordError;
      }
      const result = recorded as { receipt_id: string; result: string };
      log('process_receipt', {
        charge_id: chargeId,
        receipt_id: result.receipt_id,
        outcome: reading.outcome,
        result: result.result,
        calls: reading.calls,
        duration_ms: Date.now() - started,
        input_tokens: reading.usage?.input_tokens ?? null,
        output_tokens: reading.usage?.output_tokens ?? null,
      });
      return jsonResponse(recorded, 200);
    } catch (error) {
      if (error instanceof HttpError) {
        log('process_receipt', {
          charge_id: chargeId ?? null,
          result: error.code,
          duration_ms: Date.now() - started,
        });
        return errorResponse(error.code, HTTP_STATUS[error.code] ?? 500);
      }
      log('process_receipt', {
        charge_id: chargeId ?? null,
        result: 'internal_error',
        error: error instanceof Error ? error.name : 'unknown',
      });
      return errorResponse('INTERNAL_ERROR', 500);
    }
  };
}
