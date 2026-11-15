// Prévia do convite (docs/contratos-api.md, seção 8).
// Fatia 3: grupos. Jogos entram na fatia 8 e, até lá, `kind: game` responde
// INVALID_INPUT.
//
// Quem chama ainda não é membro, então a leitura do grupo e a URL assinada da
// foto usam a chave de serviço (docs/rls-matriz.md, fatia 3). O JWT é conferido
// aqui dentro, com `verify_jwt = false` no config.toml (research R5 de
// specs/002-grupos). A função não grava nada.
import { createClient } from '@supabase/supabase-js';
import { bearerToken, errorResponse, jsonResponse, log } from '../_shared/http.ts';

const PHOTO_URL_SECONDS = 600;

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const service = createClient(supabaseUrl, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

type GroupRow = { id: string; name: string; photo_path: string | null };

// No Supabase local, o Edge Runtime vê a API como http://kong:8000, endereço
// que o app não alcança. A URL assinada passa a usar o endereço que o cliente
// chamou (127.0.0.1 no teste, 10.0.2.2 no emulador), que o gateway repassa nos
// cabeçalhos x-forwarded-*. Na produção, SUPABASE_URL já é o endereço público,
// e a URL fica como veio.
function reachableUrl(signedUrl: string, request: Request): string {
  const internal = new URL(supabaseUrl);
  const host = request.headers.get('x-forwarded-host');
  if (internal.hostname !== 'kong' || !host) return signedUrl;

  const url = new URL(signedUrl);
  if (url.origin !== internal.origin) return signedUrl;
  url.protocol = request.headers.get('x-forwarded-proto') ?? 'http';
  url.hostname = host;
  url.port = request.headers.get('x-forwarded-port') ?? '';
  return url.toString();
}

export async function handler(request: Request): Promise<Response> {
  if (request.method !== 'POST') {
    return errorResponse('INVALID_INPUT', 422);
  }

  const token = bearerToken(request);
  const { data: auth, error: authError } = token
    ? await service.auth.getUser(token)
    : { data: { user: null }, error: null };
  const userId = auth.user?.id;
  if (authError || !userId) {
    return errorResponse('NOT_AUTHENTICATED', 401);
  }

  let body: { code?: unknown; kind?: unknown };
  try {
    body = await request.json();
  } catch {
    return errorResponse('INVALID_INPUT', 422);
  }
  const { code, kind } = body ?? {};
  if (typeof code !== 'string' || code.length === 0 || kind !== 'group') {
    return errorResponse('INVALID_INPUT', 422);
  }

  try {
    // O código é comparado exatamente, com maiúsculas e minúsculas. Grupo
    // arquivado tem o código nulo.
    const { data: group, error } = await service
      .from('groups')
      .select('id, name, photo_path')
      .eq('invite_code', code)
      .is('archived_at', null)
      .maybeSingle<GroupRow>();
    if (error) throw error;
    if (!group) {
      log('preview_invite', { kind, result: 'invite_invalid' });
      return errorResponse('INVITE_INVALID', 404);
    }

    const [member, pending, photo] = await Promise.all([
      service
        .from('group_members')
        .select('user_id', { count: 'exact', head: true })
        .eq('group_id', group.id)
        .eq('user_id', userId),
      service
        .from('group_join_requests')
        .select('id', { count: 'exact', head: true })
        .eq('group_id', group.id)
        .eq('user_id', userId)
        .eq('status', 'pending'),
      group.photo_path
        ? service.storage.from('avatars').createSignedUrl(group.photo_path, PHOTO_URL_SECONDS)
        : Promise.resolve({ data: null, error: null }),
    ]);
    if (member.error) throw member.error;
    if (pending.error) throw pending.error;
    if (photo.error) throw photo.error;

    log('preview_invite', { kind, group_id: group.id, result: 'ok' });
    return jsonResponse({
      kind: 'group',
      group_id: group.id,
      name: group.name,
      photo_url: photo.data?.signedUrl ? reachableUrl(photo.data.signedUrl, request) : null,
      is_member: (member.count ?? 0) > 0,
      has_pending_request: (pending.count ?? 0) > 0,
    });
  } catch (error) {
    log('preview_invite', { kind, result: 'internal_error', message: String(error) });
    return errorResponse('INTERNAL_ERROR', 500);
  }
}

Deno.serve(handler);
