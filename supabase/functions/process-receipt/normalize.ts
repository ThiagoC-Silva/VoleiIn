// Normalização da leitura, antes de record_receipt (docs/comprovantes-ia.md,
// seção 4). O que não se encaixa vira nulo, nunca um palpite. Dinheiro só em
// inteiros: nada de ponto flutuante (RN04, RN88).

export type PaymentStatus = 'completed' | 'scheduled' | 'other';

// O JSON do modelo, já conferido contra o schema.
export type ModelReading = {
  payment_status: PaymentStatus | null;
  amount_text: string | null;
  paid_at: string | null;
  recipient_name: string | null;
  recipient_key: string | null;
  transaction_id: string | null;
};

export type NormalizedReading = {
  amount_cents: number | null;
  paid_at: string | null;
  recipient_name: string | null;
  recipient_key: string | null;
  transaction_id: string | null;
};

// "R$ 1.234,56" vira 123456. Ponto é milhar, vírgula é decimal, duas casas.
export function normalizeAmount(text: string | null): number | null {
  if (text === null) return null;
  const value = text.replace(/R\$/g, '').replace(/\s+/g, '');
  const match = value.match(/^(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})$/);
  if (!match) return null;
  const reais = Number.parseInt(match[1].replace(/\./g, ''), 10);
  const cents = reais * 100 + Number.parseInt(match[2], 10);
  return cents > 0 && Number.isSafeInteger(cents) ? cents : null;
}

// AAAA-MM-DDTHH:MM com data e hora que existem, só de um Pix realizado. A
// conversão de America/Sao_Paulo para UTC é do SQL.
export function normalizePaidAt(
  text: string | null,
  status: PaymentStatus | null,
): string | null {
  if (text === null || status !== 'completed') return null;
  const value = text.trim();
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/);
  if (!match) return null;
  const [year, month, day, hour, minute] = match.slice(1).map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour, minute));
  const exists = date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day && date.getUTCHours() === hour && date.getUTCMinutes() === minute;
  return exists ? value : null;
}

export function normalizeName(text: string | null): string | null {
  if (text === null) return null;
  const value = text.trim().replace(/\s+/g, ' ');
  return value === '' ? null : value;
}

// Chave escondida em parte não é lida como chave (RN88b).
export function normalizeKey(text: string | null): string | null {
  if (text === null) return null;
  const value = text.trim();
  return value === '' || /[*•…]/.test(value) ? null : value;
}

// O código do Pix (EndToEnd), sem espaços e em maiúsculas (RN88d).
export function normalizeTransactionId(text: string | null): string | null {
  if (text === null) return null;
  const value = text.replace(/\s+/g, '').toUpperCase();
  return /^E\d{20}[A-Z0-9]{11}$/.test(value) ? value : null;
}

export function normalizeReading(reading: ModelReading): NormalizedReading {
  return {
    amount_cents: normalizeAmount(reading.amount_text),
    paid_at: normalizePaidAt(reading.paid_at, reading.payment_status),
    recipient_name: normalizeName(reading.recipient_name),
    recipient_key: normalizeKey(reading.recipient_key),
    transaction_id: normalizeTransactionId(reading.transaction_id),
  };
}
