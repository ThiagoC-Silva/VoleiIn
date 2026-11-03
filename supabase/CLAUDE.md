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
| `supabase migration list --linked` | Mostra quais migrações já foram aplicadas, local e remoto |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/schema.sql` | Roda as asserções de schema numa transação desfeita; imprime `SUCESSO: N asserções` ou para no primeiro `FALHOU` |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rls.sql` | Roda as asserções de acesso, simulando cada usuário como a API faz, e confere pelo catálogo o privilégio de execução de toda função de `public` e de `privado` |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/autenticacao.sql` | Roda as asserções dos gatilhos de `auth.users`: conferência do nome no cadastro, criação do perfil na confirmação do e-mail e limpeza dos aparelhos na troca de e-mail e de senha |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_grupo.sql` | Roda os cenários das funções de grupo: criar, editar, promover, remover e sair, com os avisos e os privilégios de execução |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_jogo.sql` | Roda os cenários de criar, duplicar, editar, cancelar e encerrar jogo: preço por vaga, criador confirmado, chave do recebedor, checagens de quadra e funcionamento (RN15), recálculo, remarcação, troca de recebedor, cancelamento das cobranças e pagamento liberado |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_presenca.sql` | Roda os cenários de presença: confirmação e cancelamento, cobrança e multa, lista de espera e vaga liberada, isenção do cancelante tardio, reconfirmação, marcação de falta e o aviso de prazo do grupo |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_cobranca.sql` | Roda os cenários de baixa e isenção: só o credor, só depois do encerramento, o par de autor e momento, os avisos, a troca de recebedor e a âncora da retenção (nenhuma função altera cobrança inativa depois do encerramento, salvo a falta) |
| `docker exec -i supabase_db_VoleiIn psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/testes/rpc_conta.sql` | Roda os cenários de excluir a conta: as três recusas na ordem, a anonimização do perfil e da chave dos jogos, a saída dos grupos e das filas abertas, os aparelhos e o usuário apagados e o histórico preservado |
| `supabase/testes/concorrencia.sh` | Duas sessões de verdade disputam a última vaga, a mesma quadra e a capacidade do Ginásio: confere o resultado e que a segunda esperou a trava; grava dados com ids próprios (`cc…`) e os apaga no fim, mesmo depois de um `FALHOU` |
| `CHAVE=<chave pública> supabase/testes/autenticacao_api.sh [--so 1,2] [--com-expiracao]` | Roda os cenários de autenticação pela API do Auth, lendo os códigos no Mailpit, e confere no fim o conteúdo dos cinco modelos de e-mail; imprime `SUCESSO: N cenários` ou para no primeiro `FALHOU`. `--com-expiracao` liga o código vencido, que espera cinco minutos. A chave é a pública de `supabase status`; outros parâmetros no topo do script |
| `AUTH_URL=https://<ref>.supabase.co/auth/v1 CHAVE=<chave pública do remoto> MAILPIT_URL= PSQL= EMAIL_CAIXA=<caixa real> supabase/testes/autenticacao_api.sh --com-expiracao` | A mesma rodada contra o projeto remoto. Os endereços viram `+` na caixa dada, e cada código é pedido no terminal; os avisos, o "nenhum e-mail", os modelos e as conferências de banco ficam pulados. Roda num terminal de verdade, porque lê `/dev/tty` |
| `CHAVE=<chave pública> supabase/testes/autenticacao_api.sh --impostor <gmail>` | Só cria o cadastro pendente do cenário 19 (senha e nome "Impostor", sem confirmar) e imprime o id e a senha; o resto do cenário é no celular |
| `supabase db push --linked` | Aplica no projeto remoto as migrações que faltam. Confira antes com `--dry-run`. O `--linked` mantém o alvo no remoto: o CLI avisa que a próxima versão maior vai mirar o local por padrão |
| `supabase functions deploy enviar-push` | Publica a Edge Function |

## Remoto

Um projeto só, no plano gratuito, sem segundo ambiente.

- **Projeto:** ref `zmokpmovphikmobynssy`, `https://zmokpmovphikmobynssy.supabase.co`, região São Paulo (`sa-east-1`), Postgres 17. O ref e a URL não são segredo.
- **Numa máquina nova:** `supabase login` (token da conta, gerado no painel) e `supabase link --project-ref zmokpmovphikmobynssy`. O vínculo fica em `supabase/.temp/`, fora do git, e some quando a pasta é recriada; sem ele, `db push` e `config push` não sabem a que projeto falar.
- **Migrações:** `supabase db push --linked`. `supabase migration list --linked` mostra os dois lados e tem de bater antes de concluir um passo.
- **Pausa:** no plano gratuito, o projeto pausa depois de uma semana sem uso, e o CLI responde `ProjectPausedError`. Reativa-se pelo painel ou pelo MCP do Supabase (`restore_project`), sem custo, em poucos minutos. O workflow diário do passo 10 evita a pausa.
- **Auth:** `supabase config push` leva o `[auth]` do `config.toml`. Confira o diff antes de aceitar. O `storage.vector` do diff é recusado de propósito (passaria de `false` a `true`, e o MVP não usa).
- **Site URL e redirecionamentos** vêm do `config.toml` (`site_url`, hoje `http://127.0.0.1:3000`, o do local), e é lá que se muda: um `config push` sobrescreve o painel. A URL real entra no passo 10.
- **`supabase config diff` mostra diferenças esperadas** (conferido em 2026-10-29): o SMTP, que só existe no remoto; o `pooler`; o `storage.vector`, recusado de propósito; e `auth.sms.enable_confirmations`, ligado no remoto e desligado no local, sem efeito porque o SMS está desligado. Qualquer outra diferença em `auth` é novidade e merece olhar antes de aceitar.
- **Só pelo painel:** o SMTP (Resend: host `smtp.resend.com`, usuário `resend`, a chave de API como senha) e o teto de e-mails por hora (`rate_limit.email_sent`, 30). O `config push` não os gerencia, então o `email_sent` do `config.toml` não chega ao remoto.
- **Chave pública:** `supabase projects api-keys --project-ref zmokpmovphikmobynssy`, a de tipo `publishable` (`sb_publishable_…`). A chave de serviço nunca sai do painel.
- **E-mail:** remetente `nao-responda@mail.voleiin.com.br`, pelo Resend, com o domínio `voleiin.com.br` em `p=reject` no DMARC. O registro do domínio vence em 26/10/2027; vencido, o login inteiro cai.
- **Locais no remoto:** o `seed.sql` não roda lá, e `local.criado_por` exige uma `pessoa`. O desenvolvedor cria a própria conta pelo app, apontado para o remoto, e usa o próprio id em `criado_por`, inserindo local, quadras e horários pelo editor SQL do painel. Não se cria `pessoa` sem conta no remoto, como a "Desenvolvedor" do seed local.
- **Conferir o remoto sem o CLI:** o MCP do Supabase lê tabelas, migrações e avisos de segurança; `GET /auth/v1/settings` com a chave pública mostra os provedores ligados. Escrita no remoto é do desenvolvedor, no editor SQL do painel.

## Migrações

- Crie sempre com `supabase migration new <nome>`, que gera o arquivo já prefixado pelo timestamp UTC. Nunca nomeie à mão: o timestamp é o que define a ordem de execução.
- A sequência prevista está em `docs/stack.md`: `enums`, `tabelas`, `indices`, `rls`, `autenticacao`, `ajustes_funcoes`, `ajustes_schema`, `rpc_grupo`, `rpc_jogo`, `rpc_presenca`, `rpc_cobranca`, `rpc_conta`, `visoes`, `storage`, `avisos`, `rotinas_cron`, `rpc_convite`.
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
- Toda RPC é `security definer` com `set search_path = ''` e nomes qualificados (`public.jogo`, `privado.eh_admin`), e ganha `grant execute ... to authenticated` explícito. Auxiliares internas ficam em `privado`, com `execute` revogado de `public`, `anon` e `authenticated`: só as funções `security definer` as alcançam.
- **Recusa.** Regra violada é `raise exception using errcode = 'P0001', message = '<codigo>'`, com um código estável em `snake_case` (`quadra_ocupada`, `promova_outro_admin`); falta de papel é `errcode = '42501', message = 'sem_permissao'`. O app traduz o código para o texto da tela, então o código não muda depois de publicado. Nada além do código vai na mensagem.
- **Códigos de recusa por função**, para o app traduzir. `sem_permissao` é 42501; todos os outros, P0001. "Os da RN15" são `local_invalido`, `quadra_obrigatoria`, `quadra_invalida`, `fora_do_funcionamento`, `quadra_ocupada` e `local_lotado`, de `privado.checar_rn15`.

  | Função | Códigos |
  | --- | --- |
  | `criar_grupo`, `editar_grupo` | `sem_permissao`, `nome_vazio`, `cor_invalida`, `prazo_invalido` |
  | `promover_admin` | `sem_permissao`, `nao_e_membro` |
  | `remover_membro` | `sem_permissao`, `saia_do_grupo` |
  | `sair_grupo` | `promova_outro_admin` |
  | `criar_jogo` | `sem_permissao`, `recebedor_desconhecido`, `inicio_no_passado`, `duracao_invalida`, `vagas_invalidas`, `custo_invalido`, `prazo_invalido`, `recebedor_sem_chave` e os da RN15 |
  | `duplicar_jogo` | `sem_permissao`, `inicio_no_passado`, `recebedor_sem_chave` e os da RN15 |
  | `editar_jogo` | `sem_permissao`, `jogo_fechado`, `jogo_ja_comecou`, `inicio_no_passado`, `vagas_invalidas`, `custo_invalido`, `vagas_abaixo_dos_confirmados`, `recebedor_desconhecido`, `recebedor_sem_chave` e os da RN15 |
  | `cancelar_jogo` | `sem_permissao`, `jogo_fechado`, `jogo_ja_comecou` |
  | `encerrar_jogo` | `sem_permissao`, `jogo_fechado`, `jogo_nao_terminou` |
  | `confirmar_presenca`, `cancelar_presenca` | `sem_permissao`, `jogo_fechado`, `jogo_ja_comecou` |
  | `marcar_falta` | `sem_permissao`, `jogo_nao_encerrado`, `janela_de_falta_encerrada`, `nao_confirmado` |
  | `dar_baixa`, `isentar_cobranca` | `sem_permissao`, `pagamento_nao_liberado`, `cobranca_resolvida` |
  | `excluir_conta` | `sem_permissao`, `cobranca_em_aberto`, `promova_outro_admin`, `recebedor_de_jogo_aberto`, nessa ordem: vem a primeira pendência encontrada |

  | Código | Quando |
  | --- | --- |
  | `sem_permissao` | Sem sessão, ou sem o papel da RN13 para a operação; também quando o jogo, o grupo ou a cobrança não existe |
  | `nome_vazio`, `cor_invalida`, `prazo_invalido` | Nome do grupo vazio, cor fora das seis do DESIGN.md, prazo negativo ou, no avulso, ausente |
  | `nao_e_membro` | Promover quem não está no grupo |
  | `saia_do_grupo` | O admin tenta remover a si mesmo; o caminho é sair |
  | `promova_outro_admin` | Admin único de grupo com outros membros, ao sair ou ao excluir a conta (RN30) |
  | `recebedor_desconhecido` | Recebedor que quem cria ou edita não conhece (RN24) |
  | `recebedor_sem_chave` | Recebedor sem chave no perfil e sem chave digitada (RN24) |
  | `inicio_no_passado`, `duracao_invalida`, `vagas_invalidas`, `custo_invalido` | Campos do jogo inválidos |
  | `local_invalido`, `quadra_obrigatoria`, `quadra_invalida` | Local que não existe; quadra faltando no modo `por_quadra`, ou de outro local, ou informada no `por_horario` |
  | `fora_do_funcionamento`, `quadra_ocupada`, `local_lotado` | O jogo não cabe numa faixa; a quadra já tem jogo no horário; o local atingiu a capacidade (RN15) |
  | `jogo_fechado` | O jogo não está aberto: cancelado, ou encerrado quando a operação pede aberto (e vice-versa) |
  | `jogo_ja_comecou` | Depois do início: confirmar, cancelar presença, mudar vagas ou remarcar, cancelar o jogo |
  | `vagas_abaixo_dos_confirmados` | Reduzir as vagas abaixo dos confirmados (RN06) |
  | `jogo_nao_terminou` | Encerrar à mão antes do fim do horário reservado (RN17) |
  | `jogo_nao_encerrado`, `janela_de_falta_encerrada` | Marcar falta antes do encerramento, ou depois das 24 h do encerramento previsto (RN04) |
  | `nao_confirmado` | Marcar falta de quem não estava confirmado |
  | `pagamento_nao_liberado` | Dar baixa ou isentar antes do encerramento (RN07) |
  | `cobranca_resolvida` | Dar baixa em cobrança isenta ou cancelada, ou isentar a paga ou cancelada |
  | `cobranca_em_aberto`, `recebedor_de_jogo_aberto` | Excluir a conta com cobrança pendente ou com comprovante enviado, como devedor ou credor, ou sendo recebedor de jogo aberto (RN27) |
- **Idempotência por estado.** Repetir a operação já feita não é erro: não muda nada, não grava aviso e devolve o estado atual (promover quem já é admin, remover quem já saiu).
- **Avisos.** `privado.avisar(pessoa, tipo, titulo, corpo, jogo, cobranca)` grava a linha de `notificacao` na mesma transação da mudança de estado; o push vem depois, no passo 7. Título, corpo e destinatários são os de `docs/design/telas/08-avisos/implementacao.md`, formatados no banco: datas por `privado.data_curta` (`sáb, 24 out`) e `privado.hora` (`20:00`), em horário de Brasília; dinheiro por `privado.reais` (`R$ 1.234,56`); o jogo por `privado.nome_jogo` (o grupo, ou o local no avulso). `jogo_id` e `cobranca_id` do aviso dizem para onde o toque leva: só o que a coluna "Leva a" da tabela de avisos indica. Quem faz o ato não recebe o aviso dele.
- Os testes de função ficam em `supabase/testes/rpc_*.sql`, com o arnês de `rls.sql` mais `espera_recusa(descricao, comando, codigo, estado default 'P0001')`, que exige o sqlstate e o código na mensagem.

## Acesso

- Política de linha em toda tabela, conforme a matriz de `docs/stack.md`. Cobrança e comprovante só para devedor e credor (RN19, RNF02); aviso só para o destinatário.
- `anon` não tem privilégio em nada, e privilégio padrão está revogado: **toda função RPC nova precisa de `grant execute ... to authenticated`**, senão o app recebe 42501.
- O app escreve direto só em três lugares, limitados por coluna: o próprio perfil em `pessoa`, `lida_em` em `notificacao` e apagar os próprios aparelhos em `dispositivo_push`. Registrar aparelho é pela `registrar_dispositivo`, que transfere token já registrado por outra conta.
- Auxiliares de política ficam no schema `privado`, fora da API. Vencimento e janela de falta partem de `privado.encerramento_previsto` (RN04, RN07, RN17).
- `local`, `quadra` e `horario_funcionamento` são somente leitura para qualquer cliente autenticado: a política nega escrita e só a chave de serviço grava (RN18).
- A chave de serviço nunca aparece no app nem em arquivo versionado. Segredo de Edge Function fica na função.
- O segredo do cliente web do Google mora em `supabase/.env` (`SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=...`), fora do git, e o `config.toml` o lê por `env()` no `supabase start`. Quem clona o repositório cria o seu; sem ele, o provedor Google sobe sem segredo e a entrada pelo Google falha.
