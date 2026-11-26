// process-receipt (docs/contratos-api.md, seção 8). Monta o handler pelo
// ambiente (docs/setup.md, seção 5.2). Sem ANTHROPIC_API_KEY ou RECEIPT_MODEL, a
// leitura falha e o comprovante vai para Em análise (docs/comprovantes-ia.md,
// seção 6). O SDK lê ANTHROPIC_BASE_URL, que só o servidor dos fluxos L24 e L25
// define, para falar com o dublê da Claude API (docs/testes-referencia.md, 14.8).
//
// O JWT é conferido dentro do handler, com verify_jwt = false no config.toml
// (research R7 de specs/010-pagamentos-etapa-b).
import Anthropic from '@anthropic-ai/sdk';
import { createHandler } from './handler.ts';

const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
const model = Deno.env.get('RECEIPT_MODEL');

Deno.serve(
  createHandler({
    supabaseUrl: Deno.env.get('SUPABASE_URL')!,
    anonKey: Deno.env.get('SUPABASE_ANON_KEY')!,
    serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    anthropic: apiKey ? new Anthropic({ apiKey }) : null,
    model: model || null,
  }),
);
