# VoleiIn

Aplicativo Android, em Flutter, que tira dos grupos de WhatsApp a organização de jogos de vôlei: marca o jogo, controla quem confirmou, com lista de espera, e registra o rateio da quadra. O pagamento é por Pix, direto a quem pagou a quadra, fora do app; o sistema só registra quem deve, quanto e se já pagou.

## Como é feito

Não há servidor de aplicação. São três peças:

- **Postgres do Supabase** — as regras de dinheiro em funções plpgsql, a leitura filtrada por política de linha e uma rotina por minuto em `pg_cron`.
- **Uma Edge Function** — o único ponto que fala com serviço externo, para enviar os avisos pela FCM.
- **App Flutter** (`app/`) — as telas e a leitura do comprovante no próprio aparelho.

## Documentos

- [`docs/prd.md`](docs/prd.md) — requisitos e regras de negócio; normativo.
- [`docs/modelo-de-dados.md`](docs/modelo-de-dados.md) — entidades, chaves e invariantes.
- [`docs/stack.md`](docs/stack.md) — onde cada regra mora e a ordem de implementação.
- [`docs/design/DESIGN.md`](docs/design/DESIGN.md) — aparência e textos das telas.
- [`docs/progresso.md`](docs/progresso.md) — o que já foi entregue e o passo atual.

Os comandos estão em [`CLAUDE.md`](CLAUDE.md) e em [`supabase/CLAUDE.md`](supabase/CLAUDE.md).
