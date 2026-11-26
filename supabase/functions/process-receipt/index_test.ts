// process-receipt (docs/contratos-api.md, seção 8; docs/comprovantes-ia.md).
// Cenários PR01 a PR10 de docs/testes-referencia.md, seção 14.3, e o conjunto
// fixo CF01 a CF26 (comprovantes-ia.md, seção 7), com a Claude API simulada
// por um servidor local e o Supabase local (research R7 e R10 de
// specs/010-pagamentos-etapa-b). Variáveis: as de test_support.ts.
import Anthropic from '@anthropic-ai/sdk';
import { assert, assertEquals, assertLess } from '@std/assert';
import { createHandler } from './handler.ts';
import { PROMPT } from './prompt.ts';
import {
  checkExpected,
  closeWorld,
  errorCode,
  errorReply,
  fixtureBytes,
  invoke,
  loadFixtures,
  messageReply,
  newGame,
  publishableKey,
  receiptWorld,
  resetReceipts,
  runFixture,
  secretKey,
  startClaudeMock,
  supabaseUrl,
  upload,
} from './test_support.ts';

const options = { sanitizeOps: false, sanitizeResources: false };

Deno.test('process-receipt (PR01 a PR10, CF01 a CF26)', options, async (t) => {
  const w = await receiptWorld();
  const mock = startClaudeMock();
  const handler = createHandler({
    supabaseUrl,
    anonKey: publishableKey,
    serviceKey: secretKey,
    anthropic: new Anthropic({ apiKey: 'chave-de-teste', baseURL: mock.url }),
    model: 'modelo-teste',
  });
  const fixtures = await loadFixtures();
  const cf01 = fixtures.find((f) => f.id === 'CF01')!;
  const goodReply = () => messageReply(cf01.reading);

  // Um valor novo do Fábio, com o arquivo do CF01 já no bucket.
  async function fabioWithFile() {
    await resetReceipts(w);
    mock.reset();
    const game = await newGame(w);
    const path = await upload(w, game.fabioCharge, await fixtureBytes(cf01), 'image/png', 'png');
    return { ...game, path };
  }

  try {
    await t.step('PR01 e PR10: o pagador envia o CF01; o log não leva dados pessoais', async () => {
      const game = await fabioWithFile();
      mock.replies.push(goodReply());
      const lines: string[] = [];
      const original = console.log;
      console.log = (...args: unknown[]) => lines.push(args.map(String).join(' '));
      let result;
      try {
        result = await invoke(handler, w.fabio.token, {
          charge_id: game.fabioCharge,
          storage_path: game.path,
        });
      } finally {
        console.log = original;
      }
      assertEquals(result.status, 200, JSON.stringify(result.body));
      assertEquals(
        { ...result.body, receipt_id: undefined },
        {
          receipt_id: undefined,
          result: 'approved',
          error_code: null,
          charge_status: 'paid',
          auto_reads_used: 1,
        },
        'PR01: approved, sem erro, valor paid, uma leitura',
      );

      assertEquals(mock.messages.length, 1, 'PR01: uma chamada à API');
      const request = mock.messages[0];
      const sent = JSON.stringify(request);
      const content = (request.messages as { content: Record<string, unknown>[] }[])[0].content;
      const image = content.find((block) => block.type === 'image') as {
        source: { type: string; media_type: string; data: string };
      };
      assertEquals(
        [image.source.type, image.source.media_type],
        ['base64', 'image/png'],
        'PR01: um bloco de imagem em base64',
      );
      assertEquals(request.system, PROMPT, 'PR01: o prompt do sistema da versão 1');
      assertEquals(
        [request.model, request.max_tokens, request.temperature, request.thinking],
        ['modelo-teste', 4096, undefined, undefined],
        'PR01: modelo, max_tokens 4.096, sem temperature e sem thinking',
      );
      const outputConfig = request.output_config as {
        effort: string;
        format: { type: string };
      };
      assertEquals(
        [outputConfig.effort, outputConfig.format.type],
        ['low', 'json_schema'],
        'PR01: esforço baixo e saída estruturada',
      );
      for (const leak of [game.fabioCharge, game.gameId, w.ana.id, '2084', '20,84', 'Ana Souza']) {
        assert(!sent.includes(leak), `PR01: o pedido não leva ${leak}`);
      }

      const logged = lines.join('\n');
      assert(logged.includes('process_receipt'), 'PR10: há log da leitura');
      for (
        const leak of ['ANA SOUZA LIMA', '529.982.247', '2084', '20,84', 'K4M7P2Q9R01', game.path]
      ) {
        assert(!logged.includes(leak), `PR10: o log não leva ${leak}`);
      }
    });

    await t.step('PR02: sem token e com token de conta excluída', async () => {
      const game = await fabioWithFile();
      const body = { charge_id: game.fabioCharge, storage_path: game.path };
      const none = await invoke(handler, null, body);
      const gone = await invoke(handler, w.gone.token, body);
      assertEquals(
        [none.status, errorCode(none), gone.status, errorCode(gone)],
        [401, 'NOT_AUTHENTICATED', 401, 'NOT_AUTHENTICATED'],
      );
    });

    await t.step('PR03: quem não vê o valor, o recebedor e valor que não existe', async () => {
      const game = await fabioWithFile();
      const body = { charge_id: game.fabioCharge, storage_path: game.path };
      const bruno = await invoke(handler, w.bruno.token, body);
      const ana = await invoke(handler, w.ana.token, body);
      const missing = await invoke(handler, w.fabio.token, {
        charge_id: crypto.randomUUID(),
        storage_path: game.path,
      });
      assertEquals(
        [
          bruno.status,
          errorCode(bruno),
          ana.status,
          errorCode(ana),
          missing.status,
          errorCode(missing),
        ],
        [404, 'NOT_FOUND', 403, 'NOT_CHARGE_PAYER', 404, 'NOT_FOUND'],
      );
      assertEquals(mock.messages.length, 0, 'PR03: sem chamar a API');
    });

    await t.step('PR04: valor Pago', async () => {
      const game = await fabioWithFile();
      await w.sql`
        update public.charges set status = 'paid', paid_at = now(), paid_via = 'manual'
        where id = ${game.fabioCharge}`;
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: game.path,
      });
      assertEquals([result.status, errorCode(result)], [409, 'CHARGE_NOT_PENDING']);
      assertEquals(mock.messages.length, 0, 'PR04: sem chamar a API');
    });

    await t.step(
      'PR05: caminho de outro valor, corpo sem charge_id e caminho sem arquivo',
      async () => {
        const game = await fabioWithFile();
        const other = await upload(
          w,
          game.brunoCharge,
          await fixtureBytes(cf01),
          'image/png',
          'png',
        );
        const wrongPath = await invoke(handler, w.fabio.token, {
          charge_id: game.fabioCharge,
          storage_path: other,
        });
        const noCharge = await invoke(handler, w.fabio.token, { storage_path: game.path });
        const noFile = await invoke(handler, w.fabio.token, {
          charge_id: game.fabioCharge,
          storage_path: `${game.fabioCharge}/${crypto.randomUUID()}.png`,
        });
        assertEquals(
          [
            wrongPath.status,
            errorCode(wrongPath),
            noCharge.status,
            errorCode(noCharge),
            noFile.status,
            errorCode(noFile),
          ],
          [422, 'INVALID_INPUT', 422, 'INVALID_INPUT', 422, 'RECEIPT_FILE_NOT_FOUND'],
        );
      },
    );

    await t.step('PR06: um texto gravado como image/png', async () => {
      await resetReceipts(w);
      mock.reset();
      const game = await newGame(w);
      const path = await upload(
        w,
        game.fabioCharge,
        new TextEncoder().encode('isto não é uma imagem'),
        'image/png',
        'png',
      );
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: path,
      });
      assertEquals([result.status, errorCode(result)], [422, 'RECEIPT_TYPE_INVALID']);
      assertEquals(mock.messages.length, 0, 'PR06: sem chamar a API');
      const [{ count }] = await w.sql`
        select count(*)::int from public.receipts where charge_id = ${game.fabioCharge}`;
      assertEquals(count, 0, 'PR06: sem comprovante');
    });

    await t.step('PR07a: a API devolve 500', async () => {
      const game = await fabioWithFile();
      mock.replies.push(errorReply(500), errorReply(500));
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: game.path,
      });
      assertEquals(
        [result.body.result, result.body.auto_reads_used],
        ['under_review', 0],
      );
    });

    await t.step('PR07b: a API devolve 429 e depois responde', async () => {
      const game = await fabioWithFile();
      mock.replies.push(errorReply(429), goodReply());
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: game.path,
      });
      assertEquals([result.body.result, mock.messages.length], ['approved', 2]);
    });

    await t.step('PR07c: a API não responde em 25 s', async () => {
      const game = await fabioWithFile();
      mock.replies.push({ hang: true }, { hang: true });
      const started = performance.now();
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: game.path,
      });
      const seconds = (performance.now() - started) / 1000;
      assertEquals(result.body.result, 'under_review');
      assertLess(seconds, 28, `PR07c: resultado em ${seconds.toFixed(1)} s`);
    });

    await t.step('PR08: recusa, max_tokens, JSON fora do schema e raciocínio antes', async () => {
      const skipped = async (reply: ReturnType<typeof messageReply>) => {
        const game = await fabioWithFile();
        mock.replies.push(reply);
        const result = await invoke(handler, w.fabio.token, {
          charge_id: game.fabioCharge,
          storage_path: game.path,
        });
        const [receipt] = await w.sql`
          select validation from public.receipts where id = ${result.body.receipt_id as string}`;
        return [result.body.result, receipt?.validation?.skipped ?? null];
      };
      assertEquals(
        await skipped(messageReply(cf01.reading, { stopReason: 'refusal' })),
        ['under_review', 'api_failed'],
        'PR08a: refusal',
      );
      assertEquals(
        await skipped(messageReply(cf01.reading, { stopReason: 'max_tokens' })),
        ['under_review', 'api_failed'],
        'PR08b: max_tokens',
      );
      assertEquals(
        await skipped(messageReply({ ...cf01.reading, extra: 'campo a mais' })),
        ['under_review', 'api_failed'],
        'PR08c: JSON fora do schema',
      );
      assertEquals(
        await skipped(messageReply(cf01.reading, { thinkingFirst: true })),
        ['approved', null],
        'PR08d: um bloco de raciocínio antes do texto: a leitura normal',
      );
    });

    await t.step('PR09: auto_reads_used 3', async () => {
      const game = await fabioWithFile();
      await w.sql`update public.charges set auto_reads_used = 3 where id = ${game.fabioCharge}`;
      const result = await invoke(handler, w.fabio.token, {
        charge_id: game.fabioCharge,
        storage_path: game.path,
      });
      assertEquals([result.body.result, mock.messages.length], ['under_review', 0]);
    });

    for (const fixture of fixtures) {
      await t.step(`${fixture.id}: ${fixture.title}`, async () => {
        mock.reset();
        if (fixture.reading) mock.replies.push(messageReply(fixture.reading));
        if (fixture.count_tokens) mock.inputTokens = fixture.count_tokens;
        const run = await runFixture(w, handler, fixture);
        assertEquals(checkExpected(run), [], `${fixture.id}: ${JSON.stringify(run.result.body)}`);
        if (fixture.id === 'CF25') assertEquals(mock.messages.length, 0, 'CF25: sem chamar a API');
        if (fixture.id === 'CF26') {
          assertEquals([mock.counts.length, mock.messages.length], [1, 0], 'CF26: só a contagem');
        }
      });
    }
  } finally {
    await mock.close();
    await closeWorld();
  }
});
