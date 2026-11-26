// Dublê da Claude API para o `supabase functions serve` dos fluxos L24 e L25
// (docs/testes-referencia.md, 14.8; specs/010-pagamentos-etapa-b). A
// process-receipt fala com ele pelo ANTHROPIC_BASE_URL do SDK: a função não tem
// caminho de leitura falsa. Sobe por scripts/functions-serve-stub.sh.
//
// Responde pela imagem enviada, as duas de app/integration_test/receipts_flow_test.dart:
//   - legibleReceipt (PNG branco de 2 × 2): a leitura boa do valor do Bruno no
//     jogo "Quinta aguardando conclusão" (R$ 30,00, a chave CPF da Ana, a hora
//     atual em São Paulo e um código do Pix novo a cada chamada);
//   - illegibleReceipt (PNG preto de 2 × 2): os seis campos nulos.
// Outro arquivo recebe um 400, e a leitura vai para análise.
//
//   deno run --allow-net=0.0.0.0 supabase/functions/_tests/claude_stub.ts [porta]

const LEGIBLE =
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAADklEQVR4nGP4DwYMEAoAU7oL9ZisIGcAAAAASUVORK5CYII=';
const ILLEGIBLE =
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAC0lEQVR4nGNgQAYAAA4AAamRc7EAAAAASUVORK5CYII=';

// AAAA-MM-DDTHH:MM no fuso de São Paulo, como o modelo copia do comprovante.
function nowInSaoPaulo(): string {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Sao_Paulo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date()).map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

// E, 20 dígitos e 11 letras ou dígitos (RN88d), novo a cada chamada (RN89).
function newTransactionId(): string {
  const pick = (alphabet: string, n: number) =>
    Array.from(
      crypto.getRandomValues(new Uint8Array(n)),
      (b) => alphabet[b % alphabet.length],
    ).join('');
  return `E${pick('0123456789', 20)}${pick('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 11)}`;
}

function legibleReading() {
  return {
    payment_status: 'completed',
    amount_text: 'R$ 30,00',
    paid_at: nowInSaoPaulo(),
    recipient_name: 'Ana',
    recipient_key: '529.982.247-25',
    transaction_id: newTransactionId(),
  };
}

const ILLEGIBLE_READING = {
  payment_status: null,
  amount_text: null,
  paid_at: null,
  recipient_name: null,
  recipient_key: null,
  transaction_id: null,
};

function imageData(body: Record<string, unknown>): string | null {
  const messages = body.messages as { content?: { type?: string; source?: { data?: string } }[] }[];
  const block = messages?.[0]?.content?.find((c) => c.type === 'image' || c.type === 'document');
  return block?.source?.data ?? null;
}

function apiError(status: number, message: string): Response {
  return Response.json(
    { type: 'error', error: { type: 'invalid_request_error', message } },
    { status },
  );
}

const port = Number(Deno.args[0] ?? '54399');

Deno.serve({ port, hostname: '0.0.0.0' }, async (request) => {
  const path = new URL(request.url).pathname;
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return apiError(400, 'corpo inválido');
  }
  if (path === '/v1/messages/count_tokens') return Response.json({ input_tokens: 3000 });
  if (path !== '/v1/messages') return apiError(404, `caminho ${path}`);

  const data = imageData(body);
  const reading = data === LEGIBLE
    ? legibleReading()
    : data === ILLEGIBLE
    ? ILLEGIBLE_READING
    : null;
  console.log(
    JSON.stringify({
      at: new Date().toISOString(),
      image: data === LEGIBLE ? 'legible' : data === ILLEGIBLE ? 'illegible' : 'unknown',
      reading,
    }),
  );
  if (!reading) return apiError(400, 'arquivo desconhecido do dublê');

  return Response.json({
    id: 'msg_dublê',
    type: 'message',
    role: 'assistant',
    model: String(body.model ?? 'modelo-dublê'),
    content: [{ type: 'text', text: JSON.stringify(reading) }],
    stop_reason: 'end_turn',
    stop_sequence: null,
    usage: { input_tokens: 4500, output_tokens: 300 },
  });
});
