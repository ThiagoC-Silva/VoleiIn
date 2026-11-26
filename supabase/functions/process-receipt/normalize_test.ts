// Normalização da leitura (docs/comprovantes-ia.md, seção 4). Cenários NM01 a
// NM05 de docs/testes-referencia.md, seção 14.3. Sem rede e sem banco.
import { assertEquals } from '@std/assert';
import {
  normalizeAmount,
  normalizeKey,
  normalizePaidAt,
  normalizeReading,
  normalizeTransactionId,
} from './normalize.ts';

Deno.test('NM01: valores no formato brasileiro viram centavos', () => {
  assertEquals(
    ['R$ 20,84', '20,84', 'R$ 1.234,56', 'R$20,84'].map(normalizeAmount),
    [2084, 2084, 123456, 2084],
  );
});

Deno.test('NM02: valores fora do formato, zero ou negativos ficam nulos', () => {
  assertEquals(
    ['20.84', 'R$ 20,8', 'R$ 0,00', '-20,84', '20,84 e 1,00', ''].map(normalizeAmount),
    [null, null, null, null, null, null],
  );
});

Deno.test('NM03: data e hora AAAA-MM-DDTHH:MM, que existe, de um Pix realizado', () => {
  assertEquals(
    [
      normalizePaidAt('2026-11-19T22:15', 'completed'),
      normalizePaidAt('2026-02-30T10:00', 'completed'),
      normalizePaidAt('19/11/2026 22:15', 'completed'),
      normalizePaidAt('2026-11-19T22:15', 'scheduled'),
    ],
    ['2026-11-19T22:15', null, null, null],
  );
});

Deno.test('NM04: o código do Pix sem espaços, em maiúsculas e no formato da RN88d', () => {
  const id = 'E18236120202611200115S0123456789';
  assertEquals(
    [
      normalizeTransactionId(' e18236120 202611200115\ns0123456789 '),
      normalizeTransactionId(id.slice(0, 31)),
      normalizeTransactionId(id + '0'),
      normalizeTransactionId('D' + id.slice(1)),
    ],
    [id, null, null, null],
  );
});

Deno.test('NM05: chave escondida ou vazia fica nula', () => {
  assertEquals(
    ['***.982.247-**', '529.982.247-25', '   '].map(normalizeKey),
    [null, '529.982.247-25', null],
  );
});

Deno.test('a leitura inteira, com o nome sem espaços repetidos', () => {
  assertEquals(
    normalizeReading({
      payment_status: 'completed',
      amount_text: 'R$ 20,84',
      paid_at: '2026-11-19T22:15',
      recipient_name: '  ANA   SOUZA LIMA ',
      recipient_key: '***.982.247-**',
      transaction_id: 'E18236120202611200115S0123456789',
    }),
    {
      amount_cents: 2084,
      paid_at: '2026-11-19T22:15',
      recipient_name: 'ANA SOUZA LIMA',
      recipient_key: null,
      transaction_id: 'E18236120202611200115S0123456789',
    },
  );
});
