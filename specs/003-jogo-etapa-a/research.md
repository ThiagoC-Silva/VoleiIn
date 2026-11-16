# Research: Jogo e lista de presença, etapa A (fatia 4)

Decisões técnicas que os documentos deixam para a implementação. Regra de produto não é decidida aqui.

## R1. Bloqueios e a ordem deles

- **Decision:** toda função que muda um jogo bloqueia primeiro a linha de `games` (`for update`), como pede o `contratos-api.md` (seção 1), e só depois confere acesso, papel, estado e vagas. `create_game` em grupo bloqueia a linha do grupo com o `private.lock_member_group` da fatia 3, que também confere a participação. Quando uma função precisar das duas linhas, a ordem é sempre grupo e depois jogo. `join_game` e `join_waitlist` bloqueiam só o jogo e leem `group_members` sem bloqueio.
- **Rationale:**
  - **Disputa por vaga (RN53, C01, C02, C05):** com a linha do jogo bloqueada, as entradas ficam em fila. Cada uma conta as vagas depois que a anterior gravou, então nunca entram mais pessoas que o limite, e a redução do limite também espera a entrada que chegou antes.
  - **Mesma pessoa duas vezes (C04):** a fila já resolve. O índice único `game_participants_one_slot_idx` continua como rede de segurança, e a `unique_violation` é convertida em `ALREADY_PARTICIPANT` (`contratos-api.md`, seção 1).
  - **Criação no meio do arquivamento:** o `archive_group` bloqueia o grupo e confere os jogos ativos. Com o grupo bloqueado também em `create_game`, a criação espera o arquivamento e depois não acha mais a pessoa como membro (`NOT_FOUND`), em vez de criar um jogo ativo num grupo arquivado.
  - **Saída do grupo (etapa C, C16):** a extensão de `leave_group` vai bloquear o grupo e depois os jogos. Como `join_game` não bloqueia o grupo, não há impasse: ou a entrada termina antes e a saída a vê e a retira, ou a saída apaga a participação antes e a entrada não acha mais o membro.
- **Alternatives considered:** `serializable` (o app teria de repetir as chamadas recusadas por serialização); bloqueio consultivo por jogo (faz o mesmo sem reler a linha).

## R2. Status e vagas num lugar só

- **Decision:** duas auxiliares internas: `private.occupied_slots(game_id)`, que conta as passagens `active` e `left_after_start` (RN57), e `private.refresh_game_status(game_id)`, que grava `confirmed` quando as vagas ocupadas chegam ao limite e `open` quando não, só para jogos `open` ou `confirmed`, e devolve o status anterior e o novo. As funções que mudam a lista ou o limite a chamam no fim e notificam `game_confirmed` quando o status passa de `open` a `confirmed`.
- **Rationale:** RN40 a RN42 valem igual para entradas, limite e, na etapa B, saídas e remoções. Uma auxiliar evita que cada função recalcule de um jeito.
- **Alternatives considered:** *trigger* em `game_participants` (a notificação precisaria saber quem fez a lista encher, que só a função sabe).

## R3. O código de convite antes da fatia 8

- **Decision:** `join_game` e `join_waitlist` aceitam `p_invite_code`, mas o ignoram até a fatia 8. Quem vê o jogo sem atender à RN50 recebe `NO_GAME_ACCESS`, com ou sem código.
- **Rationale:** o contrato diz que o parâmetro "é usado a partir da fatia 8" e que o código "passa a valer na fatia 8". Devolver `INVITE_INVALID` para um código certo seria falso; aceitá-lo seria antecipar o RF48. A assinatura já nasce como no contrato, para o B06 e o app não mudarem na fatia 8.
- **Alternatives considered:** recusar qualquer código com `INVALID_INPUT` (mudaria o comportamento da assinatura na fatia 8).

## R4. Ordem das validações

Segue a seção 1 do `contratos-api.md` (autenticação, existência, papel, estado e tempo, entrada). Onde o contrato lista vários códigos de um mesmo grupo, a ordem é a da lista do contrato, ajustada pelos cenários:

- **`create_game`:** `NOT_AUTHENTICATED`; `NOT_FOUND` (grupo inexistente, arquivado ou de que a pessoa não é membro); `RECEIVER_NEEDS_PIX_KEY`; `START_IN_PAST`; `INVALID_GAME_DATES`; `INVALID_INPUT`. Data nula é `INVALID_INPUT`, conferida antes das datas.
- **`update_game`:** `NOT_FOUND` (quem não vê o jogo); `NOT_GAME_ADMIN`; `GAME_NOT_OPEN`; `GAME_STARTED` (pelo início gravado); depois as datas novas e a entrada, como em `create_game`.
- **`join_game`:** `NOT_FOUND`; `NO_GAME_ACCESS`; `GAME_NOT_OPEN` (cancelado ou concluído); `GAME_STARTED`; `ALREADY_PARTICIPANT`; `GAME_FULL`.
- **`join_waitlist`:** `NOT_FOUND`; `NO_GAME_ACCESS`; `GAME_NOT_OPEN`; `GAME_STARTED`; `ALREADY_PARTICIPANT`; `GAME_NOT_FULL`; `ALREADY_ON_WAITLIST`. O O03 pede `ALREADY_PARTICIPANT` para quem está na lista cheia, então a participação vem antes das vagas.
- **`set_slot_limit`:** `NOT_FOUND`; `NOT_GAME_ADMIN`; `GAME_NOT_OPEN`; `GAME_STARTED`; `INVALID_INPUT` (limite nulo ou menor que 1); `SLOT_LIMIT_BELOW_PARTICIPANTS`. O O21 pede `INVALID_INPUT` para o limite 0 com 3 na lista, então a entrada vem antes da comparação com a lista.

## R5. Dados das notificações

- **Decision:** `private.game_notification_data(game_id)` monta o `p_data` da tabela "Dados das notificações de jogo" (`contratos-api.md`, seção 4): `game_id`, `group_name` (nulo no avulso, e lido também de grupo arquivado), `location_name` e `starts_at` em ISO 8601 (`to_jsonb(timestamptz)`). O `waitlist_slot_opened` acrescenta `reason`.
- **Avisos desta etapa:** `game_confirmed` em `join_game` e `set_slot_limit`; `game_updated` em `update_game` e na mudança efetiva de limite; `waitlist_slot_opened` com `reason: limit_increased` no aumento do limite, para cada pessoa da espera com `left_at` nulo. Sempre para quem tem passagem `active`, exceto quem fez a mudança.
- **Rationale:** um formato só para todos os eventos de jogo, que a fatia 7 transforma em texto.

## R6. Testes pgTAP com os jogos do seed

- **Decision:** os testes pgTAP que montam a própria base (os três novos de jogo, `account_security`, `groups_functions` e `groups_security`) passam a apagar, no preparo e dentro da transação, as linhas de `game_waitlist`, `game_participants`, `game_admins`, `game_limit_history` e `games`, antes das linhas de grupo. O `rollback` do fim devolve tudo. Os resultados esperados não mudam.
- **Rationale:** é o mesmo caso do research R3 de `specs/002-grupos`. O seed da fatia 4 põe Ana, Bruno e Carla nos mesmos jogos, o que é contexto compartilhado (RN107): sem a limpeza, o P01 e o P16 (Ana e Bruno sem contexto) e os casos do K que supõem contexto só pelo grupo veriam o contexto do seed. A chave Pix da Carla também não sai enquanto ela for recebedora do Jogo da Carla (RN105), e a base da seção 12 a quer sem chave: por isso os jogos saem antes das mudanças de perfil.
- **IDs de teste:** o grupo Quinta continua `...0301`, como na fatia 3, e o jogo base é o `...0401`, longe dos IDs do seed (`...0101`, `...0201` em diante). Edu, que só existe nos testes, é o `...000e` (`edu@voleiin.test`).

## R7. Concorrência com contas próprias de teste

- **Decision:** os cenários C01, C02, C04 e C05 usam 27 contas de teste (`conc-00@voleiin.test` a `conc-26@voleiin.test`), criadas pelo próprio teste, se faltarem, com a API de administração do Auth e a chave secreta do Supabase **local** (`SUPABASE_SECRET_KEY`, como no Q07 da fatia 3). Cada conta chama a API com um token assinado pelo teste com o `JWT_SECRET` do Supabase local (`supabase status -o env`), em vez de entrar com senha. A `conc-00` cadastra a própria chave Pix e cria o grupo "Concorrência", e as outras entram nele pelas funções da fatia 3 (pedido e aprovação). Cada repetição cria um jogo novo com `create_game`, enche as vagas iniciais com `join_game` e dispara as chamadas simultâneas.
- **Por que o token assinado:** o Auth local aceita 30 logins por IP a cada 5 minutos (`sign_in_sign_ups` do `config.toml`), e a pasta `_tests/` inteira passaria disso com 27 logins a mais. O token tem o mesmo formato do que o Auth emite (`sub`, `role = authenticated`, `aud`, `exp` de 1 hora), e o PostgREST o confere com a mesma chave: a chamada segue o caminho do app a partir da API. Subir o limite no `config.toml` afrouxaria também a produção no próximo `config push`. O `JWT_SECRET` é a chave de demonstração que o CLI gera para todo projeto local, não um segredo da produção (`setup.md`, seção 5).
- **Rationale:** o C02 precisa de 27 pessoas diferentes (7 ocupadas e 20 que entram), e o seed tem quatro. Contas só de teste deixam os personagens do seed e as telas do app como estavam, sem jogos e grupos sobrando na Ana. Criar um jogo por repetição evita depender das saídas, que são da etapa B. Tudo, menos a criação das contas, passa pelas funções, o mesmo caminho do app (research R4 de `specs/002-grupos`).
- **Efeito colateral:** os jogos e o grupo das contas de teste ficam no banco local até o próximo `supabase db reset`, sem efeito nos outros cenários, porque ninguém do seed participa deles.
- **Alternatives considered:** pôr as 27 contas no seed (o seed é para o desenvolvimento e a `setup.md` lista só quatro pessoas); um driver de Postgres no Deno (pacote novo).

## R8. Realtime

- **Decision:** a migração de RLS põe `games`, `game_participants` e `game_waitlist` na publicação `supabase_realtime` com `alter publication ... add table`. A identidade de réplica fica a padrão (chave primária): o app relê o repositório a cada evento e não usa o conteúdo antigo da linha (S51).
- **Rationale:** `docs/rls-matriz.md`, fatia 4, e `docs/stacks.md`, 4.1. O W15 confere a lista exata.

## R9. Jogos no detalhe do grupo, montados pelo roteador (sessão 3)

- **Decision:** a seção "Próximos jogos" do detalhe do grupo (`docs/ui/telas.md`, 7.6), com os cards, a leitura e o botão **Criar jogo**, é da feature `games` (`GroupGamesSection`). O roteador a entrega pronta à `GroupScreen`, num parâmetro, e a feature `groups` não importa nada de `games`. Puxar para baixo no detalhe do grupo relê também os jogos, pela função que o roteador passa junto.
- **Rationale:** `docs/arquitetura-app.md`, seção 2: uma feature não lê o `data` nem o `presentation` de outra. Decisão do responsável de 16/11/2026, registrada na mesma seção.
- **Alternatives considered:** o card em `shared/` e a leitura dos jogos duplicada no repositório de grupos; uma segunda exceção à regra da seção 2.

## R10. Perfil de outra pessoa na aba Jogos

- **Decision:** rota `/games/:gameId/people/:userId`, com o nome `gamePerson` e a mesma `PersonScreen`, no ramo da aba Jogos. A `/people/:userId` continua no ramo da aba Grupos.
- **Rationale:** o `go_router` não aceita duas rotas com o mesmo nome, e um caminho só pertence a um ramo do `StatefulShellRoute`. Empilhar sob o jogo mantém a barra com **Jogos** ativo e o voltar no detalhe (`docs/ui/telas.md`, 7.3).

## R11. Relógio e Realtime trocáveis nos testes

- **Decision:** `clockProvider` (`core/clock.dart`) entrega o relógio do aparelho, usado só para mostrar (selos de tempo, o pé do detalhe e o aviso "início no passado" do formulário; `docs/arquitetura-app.md`, seção 8). O `GamesRepository.watchGame(gameId, onChange)` assina `games`, `game_participants` e `game_waitlist` num canal e devolve a função que cancela a assinatura. O provider do detalhe chama `ref.invalidateSelf()` a cada aviso (seção 6).
- **Rationale:** o S47 e o S51 pedem o relógio e o Realtime trocados por dublês, e o repositório é a única camada que fala com o Supabase.

## R12. O detalhe só com as ações da etapa A

- **Decision:** nesta etapa, o pé do detalhe mostra **Entrar na lista**, **Entrar na lista de espera**, `gameFullHint`, `gameNeedsInvite`, `gameWaitlistNotice`, `gameReceiverCannotLeave` e `gameListLocked`. **Sair da lista** e **Sair da lista de espera** (etapa B) não aparecem: quem está na lista e não é o recebedor fica sem pé, e quem está na espera vê só o que a tabela da seção 7.3 lista além do botão de sair. O menu do admin tem só **Editar jogo**, e some quando não há opção; **Admins do jogo** e **Cancelar jogo** chegam na etapa C. Tocar numa pessoa da lista abre o perfil para todos; a sheet de remoção do admin chega na etapa B.
- **Rationale:** `specs/003-jogo-etapa-a/spec.md`, "Fora desta etapa", e `tasks.md`, sessão 3.

## R13. A seção do grupo e o S55

- **Decision:** a seção "Próximos jogos" e o botão **Criar jogo** do detalhe do grupo entram nesta etapa (T026, e o L15 confere o jogo no grupo). O S55, que a tabela "Cenários por etapa" põe na etapa C, é escrito já agora, sem mudar o resultado esperado. A frase da saída do grupo com jogos e a sheet de bloqueio (S56, S57) continuam na etapa C.
- **Rationale:** testar antes o que a etapa implementa (constituição, princípio III).
