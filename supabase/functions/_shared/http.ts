// Respostas das Edge Functions no formato do docs/contratos-api.md (seção 1).
// Sucesso: o objeto em snake_case. Erro: { "error": { "code", "details" } }.

const jsonHeaders = { 'Content-Type': 'application/json; charset=utf-8' };

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

export function errorResponse(
  code: string,
  status: number,
  details: Record<string, unknown> = {},
): Response {
  return jsonResponse({ error: { code, details } }, status);
}

// Log estruturado, sem dados pessoais (docs/arquitetura-app.md, 14.5).
export function log(event: string, fields: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ event, ...fields }));
}

// O token do header Authorization, sem o "Bearer ".
export function bearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization') ?? '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}
