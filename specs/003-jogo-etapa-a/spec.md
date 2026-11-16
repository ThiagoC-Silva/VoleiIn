# Feature Specification: Jogo e lista de presença, etapa A (fatia 4)

**Feature Branch**: `fatia-4/servidor-a` (sessão 2) e `fatia-4/app-a` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-16

**Status**: Draft

**Input**: User description: "Fatia 4, etapa A (Jogo e lista de presença): criar, ver e editar o jogo, inclusive o limite de vagas, com entrada na lista e na lista de espera; Meus jogos, detalhe do jogo e chave Pix do recebedor."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto (constituição, princípio I). Em caso de divergência, vale o documento citado. Escopo da fatia: `docs/plano-implementacao.md`, seção 3, Fatia 4. A fatia roda em três etapas (A, B e C), cada uma com a sua especificação e as suas sessões 2 a 4 (`docs/trabalho-com-agente.md`, 3.1). Os cenários desta etapa são os da linha **A** da tabela "Cenários por etapa" de `docs/testes-referencia.md`, seção 12.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Criar um jogo (Priority: P1)

Ana, do Vôlei de Quinta e com chave Pix, cria o jogo na Quadra do Sesc. Ela vira admin, recebedora e primeira da lista. Bruno cria um jogo avulso, fora de grupo.

**Regras:** RF26 a RF32, RF37, RN05, RN06, RN20 a RN23, RN40. **Contrato:** `create_game` (`docs/contratos-api.md`, seção 4). **Telas:** `docs/ui/telas.md`, 7.2. **Textos:** `docs/copy.md`, 8.2.

**Why this priority**: sem jogo não há lista, espera nem rateio. É o primeiro passo do objetivo da fatia.

**Independent Test**: J01 a J08, U09 a U11, S38 a S41, L15 (sem o cancelamento).

**Acceptance Scenarios**:

1. **Given** Ana membro do Quinta e com chave Pix, **When** cria o jogo, **Then** o jogo nasce Aberto, com código de convite, Ana como admin, recebedora e primeira passagem da lista, e o histórico de limite com o valor inicial (J01).
2. **Given** limite 1, **When** o jogo é criado, **Then** nasce Confirmado (J03).
3. **Given** Carla sem chave Pix, **When** tenta criar, **Then** recebe `RECEIVER_NEEDS_PIX_KEY`, e o app mostra o aviso com o atalho para cadastrar a chave (J04, S38).
4. **Given** quem não é membro do grupo, um grupo inexistente ou arquivado, **When** tenta criar, **Then** recebe `NOT_FOUND` (J05).
5. **Given** datas fora da RN23 ou entradas fora dos limites, **When** tenta criar, **Then** recebe `INVALID_GAME_DATES`, `START_IN_PAST` ou `INVALID_INPUT`, e o app barra antes do servidor o que consegue barrar (J06, J07, S40).

---

### User Story 2 - Ver os meus jogos e o detalhe (Priority: P1)

Bruno vê os próximos jogos dos grupos dele e os jogos de que participa, abre o detalhe e vê a lista, a espera, a estimativa por pessoa e, estando na lista, a chave Pix da recebedora.

**Regras:** RF44 a RF46, RN52, RN101, RN102, RN107. **Acesso:** `docs/rls-matriz.md`, fatia 4 (`can_view_game`, `get_game_groups`, `get_profile_contact`). **Telas:** `docs/ui/telas.md`, 7.1, 7.3 e 7.6 (sem o botão de criar do grupo, que vem com a etapa A no app). **Textos:** `docs/copy.md`, 8.1 e 8.3.

**Why this priority**: o "Pronto quando" exige que os participantes vejam a chave Pix do recebedor desde a criação, e que quem está fora não a veja (teste negativo), e que a lista carregue em até 2 s.

**Independent Test**: W01 a W11, W13 a W15, S36, S37, S42, S50 a S52, M06.

**Acceptance Scenarios**:

1. **Given** Ana e Bruno na lista e Carla membro fora dela, **When** cada um lê o jogo, **Then** os três veem o jogo, os admins, a lista e a espera; Diego, sem grupo e sem passagem, não vê nada (W01, W02).
2. **Given** um jogo avulso, **When** alguém fora dele lê, **Then** não vê; quem passou pela espera vê (W03).
3. **Given** um ex-membro com passagem num jogo, **When** lê os jogos, **Then** vê só aquele e recebe o nome do grupo por `get_game_groups`, mesmo com o grupo arquivado (W04, W13, W14).
4. **Given** Bruno na lista, **When** pede o contato da recebedora, **Then** recebe a chave Pix; quem está só na espera, quem cancelou, quem está fora e quem está num jogo cancelado recebem a chave nula (W08 a W10).
5. **Given** um valor Pendente devido à recebedora, **When** o pagador pede o contato, **Then** recebe a chave; depois de pago, não (W11).
6. **Given** o detalhe aberto, **When** a lista muda no servidor, **Then** a tela relê sozinha (W15, S51).

---

### User Story 3 - Entrar na lista e na lista de espera (Priority: P1)

Bruno entra na lista do jogo do Quinta. Com a lista cheia, Edu entra na espera. A disputa pela última vaga é justa.

**Regras:** RF38, RF47, RF49 (entrada), RF51, RF55, RN03, RN41, RN50 a RN53. **Contratos:** `join_game`, `join_waitlist` (`docs/contratos-api.md`, seção 4). **Telas:** `docs/ui/telas.md`, 7.3. **Textos:** `docs/copy.md`, 8.3.

**Why this priority**: "dois usuários disputam a última vaga e só um fica com ela" e "os limites de tempo funcionam no instante exato do início" estão no "Pronto quando".

**Independent Test**: O01 a O07, T03 a T05, C01, C02, C04, S42.

**Acceptance Scenarios**:

1. **Given** um jogo Aberto, **When** Bruno entra, **Then** ganha uma passagem ativa; ao encher, o jogo vira Confirmado e os outros participantes são avisados (O01, O02).
2. **Given** a lista cheia, **When** Edu tenta entrar, **Then** recebe `GAME_FULL` e pode entrar na espera; com vaga, a espera recusa com `GAME_NOT_FULL` (O03, O04).
3. **Given** quem já está na lista ou na espera, **When** tenta entrar de novo, **Then** recebe `ALREADY_PARTICIPANT` ou `ALREADY_ON_WAITLIST`, mesmo em chamadas simultâneas (O03, O05, C04).
4. **Given** quem não vê o jogo, **When** tenta entrar, **Then** recebe `NOT_FOUND` (O06).
5. **Given** o início em `now()` ou antes, ou o jogo cancelado, **When** alguém tenta entrar, **Then** recebe `GAME_STARTED` ou `GAME_NOT_OPEN`; 1 µs antes do início, entra (O07, T03 a T05).
6. **Given** uma ou poucas vagas, **When** muitas pessoas entram ao mesmo tempo, **Then** só entram tantas quantas vagas havia, e as outras recebem `GAME_FULL` (C01, C02).

---

### User Story 4 - Editar o jogo e o limite de vagas (Priority: P2)

Ana, admin do jogo, troca o local e o horário e aumenta ou reduz o limite de vagas antes do início.

**Regras:** RF36, RF52, RF53, RN23, RN33 a RN35, RN41, RN42, RN59. **Contratos:** `update_game`, `set_slot_limit`. **Telas:** `docs/ui/telas.md`, 7.4. **Textos:** `docs/copy.md`, 8.2.

**Why this priority**: o status passar entre Aberto e Confirmado nas mudanças de limite está no "Pronto quando", e a tela de edição nasce inteira nesta etapa.

**Independent Test**: J09 a J13, O20 a O23, C05, S53.

**Acceptance Scenarios**:

1. **Given** Ana admin, **When** edita os dados, **Then** eles são gravados e os participantes ativos são avisados, exceto Ana (J09).
2. **Given** um não admin ou alguém fora do jogo, **When** tenta editar, **Then** recebe `NOT_GAME_ADMIN` ou `NOT_FOUND` (J10).
3. **Given** o jogo iniciado ou cancelado, **When** Ana edita, **Then** recebe `GAME_STARTED` ou `GAME_NOT_OPEN` (J11, O23).
4. **Given** um cancelamento já classificado como fora do prazo, **When** o prazo muda, **Then** a classificação não muda (J13, RN35).
5. **Given** a lista cheia e alguém na espera, **When** Ana aumenta o limite, **Then** o jogo volta a Aberto, a espera é avisada e o histórico ganha uma linha (O20).
6. **Given** um limite abaixo dos participantes, **When** Ana reduz, **Then** recebe `SLOT_LIMIT_BELOW_PARTICIPANTS`; reduzir até o número de participantes confirma o jogo (O21); o mesmo limite não muda nada (O22).
7. **Given** uma entrada e uma redução simultâneas, **When** as duas chegam, **Then** as vagas ocupadas nunca passam do limite (C05).

---

### Edge Cases

Cada caso está decidido no documento citado:

- Início exatamente em `now()`: `GAME_STARTED` (T04, T05, RN03).
- Prazo igual ao início: aceito (J06, RN23).
- Jogo que termina no dia seguinte: o app mostra a dica, e os instantes vão em UTC (U10, S40).
- Valor digitado além de `2147483647`: o dígito a mais é ignorado (U09).
- Estimativa por pessoa sempre arredondada para cima, só com inteiros (U11).
- Ex-membro com passagem: vê o jogo, mas a entrada recebe `NO_GAME_ACCESS` (`contratos-api.md`, `join_game`); o cenário H10 é da etapa C.
- Jogo avulso de outra pessoa: só com o convite, que chega na fatia 8 (S42).
- `join_game` respondendo `GAME_FULL` com a tela desatualizada: a tela relê e oferece a espera (S46 é da etapa B; nesta etapa, os erros que indicam dados mudados fazem a tela reler, `docs/ui/telas.md`, seção 7).
- Fonte do sistema em 150% e TalkBack nas telas da etapa: S59 e S60, só com as telas desta etapa.
- `anon` não lê nada (W07).

## Requirements *(mandatory)*

### Functional Requirements

Os requisitos são os de `docs/requisitos.md` e as regras, as de `docs/regras-negocio.md`. Esta lista só os liga às histórias e aos cenários de `docs/testes-referencia.md`, seção 12.

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | RF26, RF27, RF28, RF30, RN20, RN21, RN23 | 1 | J01, J02, J05 a J08, S39 a S41, L15 |
| FR-002 | RF29, RN05, RN06 (estimativa só informativa) | 1, 2 | J07, U09, U11, S41 |
| FR-003 | RF31, RF32, RN22, RN28 | 1 | J01, J04, S38 |
| FR-004 | RF37, RF38, RN40 a RN42 (entradas e limite) | 1, 3, 4 | J03, O01, O02, O20, O21 |
| FR-005 | RF44, RF46, RN52 | 2 | W01 a W04, W13, W14, S36, S37, S50 |
| FR-006 | RF45, RN102 (chave Pix pelo `get_profile_contact`) | 2 | W08 a W11, S42, S44 (só a chave e a cópia; a saída é da etapa B) |
| FR-007 | RF47, RF55, RN03, RN50, RN51 | 3 | O01 a O07, T03 a T05, S42 |
| FR-008 | RF49 (entrada na espera), RN51, RN54 | 3 | O03, O04, T05 |
| FR-009 | RF51, RN53 (disputa justa) | 3 | C01, C02, C04, C05 |
| FR-010 | RF36, RN23, RN33 a RN35 | 4 | J09 a J13, S53 |
| FR-011 | RF52, RF53, RN59 | 4 | O20 a O23, C05, S53 |
| FR-012 | Atualização ao vivo (`docs/stacks.md`, 4.1; `docs/rls-matriz.md`, fatia 4) | 2 | W15, S51 |
| FR-013 | Eventos `game_confirmed`, `game_updated` e `waitlist_slot_opened` (`reason: limit_increased`) com os dados da seção 4 do `contratos-api.md` (texto final e push na fatia 7) | 3, 4 | O02, J09, O20, O21 |
| FR-014 | Listas esperadas de políticas, privilégios e funções da etapa A (`docs/rls-matriz.md`, fatia 4) | Todas | B03, B04, B06 |
| FR-015 | Erros convertidos em texto do catálogo (`docs/copy.md`, 8.8), com os códigos das funções desta etapa | Todas | E15 |
| FR-016 | RNF04: a lista carrega em até 2 s | 2 | M06 |

### Key Entities

Definidas em `docs/modelo-dados.md`, 4.3. Nenhuma tabela nova: todas nasceram na fatia 1.

- **Jogo (`games`)**: grupo ou avulso, local, datas, valor total, limite, status, recebedor e código de convite.
- **Admin do jogo (`game_admins`)**: quem administra; o criador, sem `added_by`.
- **Passagem (`game_participants`)**: cada entrada de uma pessoa na lista, com a ordem de entrada.
- **Espera (`game_waitlist`)**: uma linha por pessoa, mantida com `left_at` quando ela sai.
- **Histórico de limite (`game_limit_history`)**: cada valor do limite, gravado pela *trigger*.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Os itens do "Pronto quando" da fatia 4 que cabem nesta etapa são conferidos, cada um com o seu cenário: a disputa pela última vaga (C01), o instante exato do início (T04, T05), Aberto e Confirmado nas entradas e nas mudanças de limite (O02, O20, O21), a chave Pix do recebedor (W08 a W10) e a lista em até 2 s (M06).
- **SC-002**: Todos os cenários automáticos da linha A da seção 12 de `docs/testes-referencia.md` passam, e nenhum resultado esperado foi alterado.
- **SC-003**: Os cenários de concorrência C01, C02, C04 e C05 dão o resultado esperado em 50 de 50 repetições.
- **SC-004**: Ninguém lê jogo, lista, espera, admins, histórico de limite, chave Pix ou nome de grupo sem o papel ou o contexto da `docs/rls-matriz.md` (fatia 4): todos os casos negativos desta etapa têm teste que passa.
- **SC-005**: Ana cria um jogo pelo grupo e o vê no grupo e em Meus jogos, com ela na lista e a chave Pix, no fluxo L15, sem ajuda.
- **SC-006**: As telas desta etapa funcionam com a fonte do sistema em 150%, sem nada cortado (S59), sem texto fora do catálogo e sem cor fora do tema.

## Assumptions

- A documentação da fatia 4 foi aprovada e entrou na `main` em 16/11/2026 (PR #10), com os PNGs de `docs/ui/referencias/fatia-4/`.
- A fatia 3 está concluída: grupos, membros, `shares_context` e as funções auxiliares de grupo.
- `join_waitlist` entra nesta etapa, porque os cenários O03, O04, O06, O07 e T05 da linha A a usam e a tela do detalhe oferece **Entrar na lista de espera** (S42). `leave_waitlist` fica na etapa B.
- `get_profile_contact` nasce inteira nesta etapa (telefone e chave), porque o W08 confere os dois. A linha **Telefone** no perfil de outra pessoa (S58, RF101) é da etapa C.
- Dados de etapas seguintes que um cenário precisa (passagem cancelada, linha da espera, valor a pagar) são inseridos direto, como `postgres` (`docs/testes-referencia.md`, seção 12).
- **Fora desta etapa:** saídas, remoção, saída da espera e os cenários de concorrência C03 e C06 (etapa B); admins do jogo, cancelamento, saída do grupo com jogos, telefone visível e C07 e C16 (etapa C). **Fora da fatia** (`docs/plano-implementacao.md`, fatia 4): conclusão, multas e rateio, troca de recebedor e entrada pelo link.
- O seed ganha os jogos da `docs/setup.md`, seção 8, que os fluxos de integração usam.
