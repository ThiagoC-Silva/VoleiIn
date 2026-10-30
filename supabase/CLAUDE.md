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
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql` | Roda as asserções dos gatilhos de `auth.users`: conferência do nome no cadastro, criação do perfil na confirmação do e-mail e limpeza dos aparelhos na troca de e-mail e de senha |
| `CHAVE=<chave pública> supabase/testes/autenticacao_api.sh [--so 1,2] [--com-expiracao]` | Roda os cenários de autenticação pela API do Auth, lendo os códigos no Mailpit, e confere no fim o conteúdo dos cinco modelos de e-mail; imprime `SUCESSO: N cenários` ou para no primeiro `FALHOU`. `--com-expiracao` liga o código vencido, que espera cinco minutos. A chave é a pública de `supabase status`; outros parâmetros no topo do script |
| `AUTH_URL=https://<ref>.supabase.co/auth/v1 CHAVE=<chave pública do remoto> MAILPIT_URL= PSQL= EMAIL_CAIXA=<caixa real> supabase/testes/autenticacao_api.sh --com-expiracao` | A mesma rodada contra o projeto remoto. Os endereços viram `+` na caixa dada, e cada código é pedido no terminal; os avisos, o "nenhum e-mail", os modelos e as conferências de banco ficam pulados. Roda num terminal de verdade, porque lê `/dev/tty` |
| `CHAVE=<chave pública> supabase/testes/autenticacao_api.sh --impostor <gmail>` | Só cria o cadastro pendente do cenário 19 (senha e nome "Impostor", sem confirmar) e imprime o id e a senha; o resto do cenário é no celular |
| `supabase db push` | Aplica no projeto remoto as migrações que faltam |
| `supabase functions deploy enviar-push` | Publica a Edge Function |

## Remoto

Um projeto só, no plano gratuito, sem segundo ambiente.

- **Projeto:** ref `zmokpmovphikmobynssy`, `https://zmokpmovphikmobynssy.supabase.co`, região São Paulo (`sa-east-1`), Postgres 17. O ref e a URL não são segredo.
- **Numa máquina nova:** `supabase login` (token da conta, gerado no painel) e `supabase link --project-ref zmokpmovphikmobynssy`. O vínculo fica em `supabase/.temp/`, fora do git, e some quando a pasta é recriada; sem ele, `db push` e `config push` não sabem a que projeto falar.
- **Migrações:** `supabase db push`. `supabase migration list` mostra os dois lados e tem de bater antes de concluir um passo.
- **Auth:** `supabase config push` leva o `[auth]` do `config.toml`. Confira o diff antes de aceitar. O `storage.vector` do diff é recusado de propósito (passaria de `false` a `true`, e o MVP não usa).
- **Site URL e redirecionamentos** vêm do `config.toml` (`site_url`, hoje `http://127.0.0.1:3000`, o do local), e é lá que se muda: um `config push` sobrescreve o painel. A URL real entra no passo 10.
- **Só pelo painel:** o SMTP (Resend: host `smtp.resend.com`, usuário `resend`, a chave de API como senha) e o teto de e-mails por hora (`rate_limit.email_sent`, 30). O `config push` não os gerencia, então o `email_sent` do `config.toml` não chega ao remoto.
- **Chave pública:** `supabase projects api-keys --project-ref zmokpmovphikmobynssy`, a de tipo `publishable` (`sb_publishable_…`). A chave de serviço nunca sai do painel.
- **E-mail:** remetente `nao-responda@mail.voleiin.com.br`, pelo Resend, com o domínio `voleiin.com.br` em `p=reject` no DMARC. O registro do domínio vence em 26/10/2027; vencido, o login inteiro cai.
- **Conferir o remoto sem o CLI:** o MCP do Supabase lê tabelas, migrações e avisos de segurança; `GET /auth/v1/settings` com a chave pública mostra os provedores ligados. Escrita no remoto é do desenvolvedor, no editor SQL do painel.

## Migrações

- Crie sempre com `supabase migration new <nome>`, que gera o arquivo já prefixado pelo timestamp UTC. Nunca nomeie à mão: o timestamp é o que define a ordem de execução.
- A sequência prevista está em `docs/stack.md`: `enums`, `tabelas`, `indices`, `rls`, `autenticacao`, `rpc_grupo`, `rpc_jogo`, `rpc_presenca`, `rpc_cobranca`, `storage`, `avisos`, `rotinas_cron`, `rpc_convite`.
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
- O app escreve direto só em três lugares, limitados por coluna: o próprio perfil em `pessoa`, `lida_em` em `notificacao` e apagar os próprios aparelhos em `dispositivo_push`. Registrar aparelho é pela `registrar_dispositivo`, que transfere token já registrado por outra conta.
- Auxiliares de política ficam no schema `privado`, fora da API. Vencimento e janela de falta partem de `privado.encerramento_previsto` (RN04, RN07, RN17).
- `local`, `quadra` e `horario_funcionamento` são somente leitura para qualquer cliente autenticado: a política nega escrita e só a chave de serviço grava (RN18).
- A chave de serviço nunca aparece no app nem em arquivo versionado. Segredo de Edge Function fica na função.
- O segredo do cliente web do Google mora em `supabase/.env` (`SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...`), fora do git, e o `config.toml` o lê por `env()` no `supabase start`. Quem clona o repositório cria o seu; sem ele, o provedor Google sobe sem segredo e a entrada pelo Google falha.
