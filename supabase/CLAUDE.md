# supabase/

O banco Postgres do Supabase. Aqui vive **todo** o cálculo e toda transição de estado do rateio; o app só chama e lê. O mapa completo está em `docs/stack.md`, seção "Onde cada regra mora".

## Comandos

Exigem Docker rodando. Executar da raiz do repositório.

| Comando | O que faz |
| --- | --- |
| `supabase start` | Sobe o Supabase local: Postgres, Auth, Storage e Studio |
| `supabase stop` | Derruba o local |
| `supabase migration new <nome>` | Cria `migrations/<timestamp>_<nome>.sql`, vazio |
| `supabase db reset` | Recria o banco local do zero, roda todas as migrações e o `seed.sql` |
| `supabase migration list` | Mostra quais migrações já foram aplicadas, local e remoto |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql` | Roda as asserções de schema numa transação desfeita; imprime `SUCESSO: N asserções` ou para no primeiro `FALHOU` |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql` | Roda as asserções de acesso, simulando cada usuário como a API faz |
| `supabase db push` | Aplica no projeto remoto as migrações que faltam |
| `supabase functions deploy enviar-push` | Publica a Edge Function |

## Migrações

- Crie sempre com `supabase migration new <nome>`, que gera o arquivo já prefixado pelo timestamp UTC. Nunca nomeie à mão: o timestamp é o que define a ordem de execução.
- A sequência prevista está em `docs/stack.md`: `enums`, `tabelas`, `indices`, `rls`, `rpc_jogo`, `rpc_presenca`, `rpc_cobranca`, `rotinas_cron`, `storage`.
- **Nunca edite uma migração já aplicada.** Corrija criando a próxima. O banco remoto não roda de novo um arquivo que já rodou, então editar faz local e remoto divergirem em silêncio.
- Valide com `supabase db reset`, que recria o banco local do zero, roda todas as migrações em ordem e aplica o `seed.sql`. Se isso passa de um banco vazio, a sequência está consistente.
- `seed.sql` guarda os locais, quadras e horários do piloto. São dados mantidos pelo desenvolvedor, não escritos pelo app (RN18).

## SQL

- Nomes de tabela e coluna em `snake_case` português, exatamente como em `docs/modelo-de-dados.md`.
- Toda tabela tem `id uuid primary key default gen_random_uuid()`, `criado_em` e `atualizado_em`.
- Dinheiro é `integer` em centavos. Data e hora é `timestamptz`, gravado em UTC.
- Hora de regra vem de `now()` no banco, nunca de parâmetro enviado pelo app (RNF08).
- A unicidade de `comprovante.id_transacao` é **índice parcial**, com `where id_transacao is not null`: vários comprovantes ilegíveis entram sem identificador e não podem disputar entre si (RN10).
- As invariantes de `docs/modelo-de-dados.md` que uma chave estrangeira não garante viram `check`, `trigger` ou validação dentro da função — nunca ficam só no app.

## Funções

- Toda função de mutação é `security definer`, valida o papel de quem chama (RN13) e é idempotente por requisição (RNF10).
- `confirmar_presenca` trava a linha do jogo e conta os confirmados dentro da transação; duas confirmações simultâneas para a última vaga não podem gerar dois confirmados (RNF09).
- Uma função por operação que muda estado. A lista prevista e as regras que cada uma carrega estão em `docs/stack.md`.

## Acesso

- Política de linha em toda tabela, conforme a matriz de `docs/stack.md`. Cobrança e comprovante só para devedor e credor (RN19, RNF02); aviso só para o destinatário.
- `anon` não tem privilégio em nada, e privilégio padrão está revogado: **toda função RPC nova precisa de `grant execute ... to authenticated`**, senão o app recebe 42501.
- O app escreve direto só em três lugares, limitados por coluna: o próprio perfil em `pessoa`, `lida_em` em `notificacao` e os próprios aparelhos em `dispositivo_push`.
- Auxiliares de política ficam no schema `privado`, fora da API. Vencimento e janela de falta partem de `privado.encerramento_previsto` (RN04, RN07, RN17).
- `local`, `quadra` e `horario_funcionamento` são somente leitura para qualquer cliente autenticado: a política nega escrita e só a chave de serviço grava (RN18).
- A chave de serviço nunca aparece no app nem em arquivo versionado. Segredo de Edge Function fica na função.
