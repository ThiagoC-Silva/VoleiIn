// Conjunto fixo com a Claude API real (docs/comprovantes-ia.md, seções 7 e 9;
// research R10 e R11 de specs/010-pagamentos-etapa-b). Roda cada exemplo de
// ponta a ponta contra o Supabase local, compara a leitura com a do <id>.json,
// confere o resultado e imprime o tempo, os tokens e o custo. Não roda no CI:
// cada execução gasta crédito da Claude API.
//
//   # em supabase/functions/, com o Supabase local de pé
//   eval "$(supabase status -o env | grep -E '^(API_URL|PUBLISHABLE_KEY|SECRET_KEY|JWT_SECRET)=')"
//   SUPABASE_URL="$API_URL" SUPABASE_PUBLISHABLE_KEY="$PUBLISHABLE_KEY" \
//     SUPABASE_SECRET_KEY="$SECRET_KEY" SUPABASE_JWT_SECRET="$JWT_SECRET" \
//     deno task receipts:live claude-haiku-5-5
//
// A chave vem de ANTHROPIC_API_KEY, lida do supabase/functions/.env pela task.
import Anthropic from '@anthropic-ai/sdk';
import { createHandler } from './handler.ts';
import { type ModelReading, normalizeReading } from './normalize.ts';
import {
  checkExpected,
  closeWorld,
  type FixtureRun,
  loadFixtures,
  publishableKey,
  receiptWorld,
  runFixture,
  secretKey,
  supabaseUrl,
} from './test_support.ts';

// Preço por milhão de tokens, entrada e saída (comprovantes-ia.md, seção 9).
const PRICES: Record<string, [number, number]> = {
  'claude-opus-5-5': [4, 20],
  'claude-sonnet-5-5': [2, 10],
  'claude-haiku-5-5': [0.1, 0.5],
};

const model = Deno.args[0] ?? Deno.env.get('RECEIPT_MODEL');
const only = Deno.args[1]?.split(',');
if (!model || !(model in PRICES)) {
  console.error(`Uso: deno task receipts:live <${Object.keys(PRICES).join(' | ')}> [CF01,CF02]`);
  Deno.exit(2);
}
if (!Deno.env.get('ANTHROPIC_API_KEY')) {
  console.error('Falta ANTHROPIC_API_KEY em supabase/functions/.env (docs/setup.md, 6.3).');
  Deno.exit(2);
}

type Usage = { input_tokens?: number; output_tokens?: number };

function costOf(usage: Usage | undefined): number {
  const [input, output] = PRICES[model!];
  return ((usage?.input_tokens ?? 0) * input + (usage?.output_tokens ?? 0) * output) / 1e6;
}

// O que o modelo leu, normalizado, contra o esperado. Devolve os campos que
// diferem.
function fieldDiffs(run: FixtureRun): string[] {
  const expected = run.fixture.reading;
  const extraction = run.receipt?.extraction as { response?: ModelReading } | null;
  const actual = extraction?.response;
  if (!expected || !actual) return [];
  const a = { payment_status: actual.payment_status, ...normalizeReading(actual) };
  const e = {
    payment_status: expected.payment_status,
    ...normalizeReading(expected as ModelReading),
  };
  return Object.keys(e).filter((k) =>
    (a as Record<string, unknown>)[k] !== (e as Record<string, unknown>)[k]
  ).map((k) =>
    `${k}: lido ${JSON.stringify((a as Record<string, unknown>)[k])}, esperado ${
      JSON.stringify((e as Record<string, unknown>)[k])
    }`
  );
}

const w = await receiptWorld();
const handler = createHandler({
  supabaseUrl,
  anonKey: publishableKey,
  serviceKey: secretKey,
  anthropic: new Anthropic(),
  model,
});

const fixtures = (await loadFixtures()).filter((f) => !only || only.includes(f.id));
const runs: FixtureRun[] = [];
console.log(`Modelo: ${model}. ${fixtures.length} exemplos.\n`);
for (const fixture of fixtures) {
  const run = await runFixture(w, handler, fixture);
  runs.push(run);
  const problems = checkExpected(run);
  const usage = (run.receipt?.extraction as { usage?: Usage } | null)?.usage;
  const diffs = fieldDiffs(run);
  console.log(
    `${fixture.id} ${problems.length ? 'ERRO' : 'ok  '} ${
      String(run.result.body.result).padEnd(12)
    } ` +
      `${(run.ms / 1000).toFixed(1)} s  ${usage?.input_tokens ?? '-'}/${
        usage?.output_tokens ?? '-'
      } tokens  ` +
      `US$ ${costOf(usage).toFixed(4)}`,
  );
  for (const line of [...problems, ...diffs]) console.log(`     ${line}`);
}
await closeWorld();

// Resumo, no formato da tabela da seção 9.
const number = (id: string) => Number(id.slice(2));
const wrongApprovals = runs.filter((r) =>
  number(r.fixture.id) >= 11 && number(r.fixture.id) <= 24 &&
  r.fixture.expected.result !== 'approved' && r.result.body.result === 'approved'
);
const goodToReview = runs.filter((r) =>
  number(r.fixture.id) <= 10 && r.result.body.result !== 'approved'
);
const read = runs.filter((r) => (r.receipt?.extraction as { usage?: Usage } | null)?.usage);
const times = read.map((r) => r.ms / 1000).sort((a, b) => a - b);
const median = times.length ? times[Math.floor((times.length - 1) / 2)] : 0;
const costs = read.map((r) => costOf((r.receipt!.extraction as { usage?: Usage }).usage));
const total = costs.reduce((a, b) => a + b, 0);
console.log(`
Aprovações indevidas (CF11 a CF24): ${wrongApprovals.length} ${
  wrongApprovals.map((r) => r.fixture.id).join(' ')
}
Bons que foram para análise (CF01 a CF10): ${goodToReview.length} ${
  goodToReview.map((r) => r.fixture.id).join(' ')
}
Tempo mediano e máximo: ${median.toFixed(1)} s e ${(times.at(-1) ?? 0).toFixed(1)} s
Custo médio por leitura: US$ ${(costs.length ? total / costs.length : 0).toFixed(4)}; total US$ ${
  total.toFixed(4)
}`);

// Critério da seção 7: nenhuma aprovação indevida e até 1 bom para análise.
const passed = wrongApprovals.length === 0 && goodToReview.length <= 1;
console.log(passed ? '\nPASSOU no critério da seção 7.' : '\nREPROVADO no critério da seção 7.');
Deno.exit(passed ? 0 : 1);
