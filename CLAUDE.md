# VoleiIn

Aplicativo Android em Flutter que substitui a organização de jogos de vôlei feita hoje em grupos de WhatsApp: marca o jogo, controla quem confirmou com lista de espera e registra o rateio da quadra. O pagamento acontece fora da plataforma, por Pix direto a quem pagou a quadra; o sistema apenas registra quem deve, quanto e se já pagou.

## Fonte de verdade

Os três documentos de `docs/` estão fechados. Leia o que for relevante antes de implementar.

- `docs/prd.md` — **normativo**: requisitos (RF01–RF40), regras de negócio (RN01–RN30), requisitos não funcionais (RNF01–RNF12), decisões tomadas e o que ficou fora do MVP. Em qualquer divergência, o PRD vence.
- `docs/modelo-de-dados.md` — as treze entidades, com diagrama, chaves estrangeiras, unicidades, catálogo de enums e as invariantes que o diagrama não expressa.
- `docs/stack.md` — onde cada regra mora, as funções previstas, a estrutura de pastas e a ordem de implementação.

IMPORTANT: se uma regra parecer ausente, ambígua ou contraditória, pergunte. Não invente regra, campo, enum nem entidade que não esteja nos documentos — lacuna aqui é decisão de produto, não de código.

## Arquitetura em três peças

Não existe servidor de aplicação. O sistema é:

- **Postgres do Supabase** — funções plpgsql com todas as regras, política de linha para leitura, e `pg_cron` rodando uma varredura por minuto para encerramento, vencimento, janela de falta e descarte de comprovante.
- **Uma Edge Function** — o único ponto que fala com serviço externo, acionada por `pg_net` para enviar à FCM.
- **App Flutter** — telas e leitura do comprovante no aparelho.

Qualquer proposta que acrescente um servidor, um host de cron ou uma fila contraria o desenho (RNF12).

## Regras invioláveis

- **O app nunca escreve nas tabelas do rateio.** Toda mutação passa por função plpgsql chamada por RPC; leitura é consulta direta filtrada por política de linha. É o que mantém cálculo, hora de regra e transição de estado dentro da transação (RNF08, RNF09, RNF10).
- **Dinheiro é inteiro em centavos**, nunca float: R$ 18,29 é `1829` e R$ 10,50 é `1050`. O valor por vaga é o custo total dividido pelas vagas, arredondado para cima no **centavo**, não no real — 10000 entre 7 vagas dá `1429` (RN01, RN16).
- **Hora de regra é a hora do servidor**, nunca a do aparelho. Grave em UTC e converta para horário de Brasília na borda (RN02, RNF08).
- Todo identificador é UUID. `Pessoa.id` espelha o id de `auth.users`, e a **ausência de chave estrangeira entre as duas é deliberada** — ver `docs/stack.md`, seção Autenticação. Não "corrija" isso.
- `Comprovante.resultado` é calculado no servidor a partir dos campos lidos. O app informa o que leu, nunca o veredito (RN09).
- **Nenhum custo variável por evento.** Tudo roda em plano gratuito. Não proponha serviço pago sem dizer o preço e perguntar antes.
- Não implemente o que está em "Fora do MVP" (`docs/prd.md`): sem gateway de pagamento, sem reserva de quadra, sem cadastro de locais pelo usuário, sem jogo recorrente, sem reputação, sem chat, sem iOS, sem web, sem painel administrativo.

## Idioma

- Identificadores de domínio em português, como no modelo de dados: tabelas `pessoa`, `jogo`, `cobranca`, `participacao`; colunas `custo_total`, `prazo_cancelamento_horas`, `chave_pix_recebedor`; valores de enum `lista_espera`, `cancelamento_tardio`, `comprovante_enviado`.
- Comentários, mensagens de commit e documentação em português.
- Palavras-chave da linguagem e API de biblioteca ficam no original.

## Ordem de trabalho

`docs/stack.md` define dez passos, e cada um fecha antes do seguinte começar. O que já foi entregue e qual é o passo atual estão em `docs/progresso.md`: **leia esse arquivo antes de implementar** e registre nele ao fechar um passo.

Documentação antes de código: não comece a implementar enquanto uma decisão de produto estiver aberta. Feche o documento primeiro, code em outra rodada.

## Comandos

Os comandos do Supabase estão em `supabase/CLAUDE.md`. O projeto Flutter ainda não foi inicializado: ao criá-lo, registre aqui os comandos de build e de teste.
