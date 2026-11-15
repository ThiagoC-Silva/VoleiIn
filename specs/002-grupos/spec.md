# Feature Specification: Grupos (fatia 3)

**Feature Branch**: `fatia-3/servidor` (sessão 2) e `fatia-3/app` (sessão 3). O *branch* numérico do Spec Kit não é usado (`docs/trabalho-com-agente.md`, seção 3.1)

**Created**: 2026-11-15

**Status**: Draft

**Input**: User description: "Fatia 3 — Grupos (docs/plano-implementacao.md, fatia 3). A pessoa cria um grupo, convida por código e administra os membros."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto (constituição, princípio I). Em caso de divergência, vale o documento citado. Escopo, "Pronto quando" e "Fora de escopo": `docs/plano-implementacao.md`, seção 3, Fatia 3. A fatia roda em quatro sessões (`docs/trabalho-com-agente.md`, 3.1): esta especificação cobre a fatia inteira, e o `tasks.md` separa as tarefas do servidor (sessão 2) das do app (sessão 3).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Criar um grupo (Priority: P1)

Ana cria o grupo "Vôlei de Quinta", com ou sem foto, e vira a admin dele.

**Regras:** RF14, RF18 (foto), RN10, RN11, RN106. **Contratos:** `create_group`, `update_group` (`docs/contratos-api.md`, seção 3). **Telas:** `docs/ui/telas.md`, 6.2. **Textos:** `docs/copy.md`, 7.2.

**Why this priority**: sem grupo não há convite, membros nem jogos (fatia 4). É o primeiro passo do "Pronto quando".

**Independent Test**: Ana logada cria um grupo e o vê em Meus grupos, com o selo Admin. Cenários G01 a G03, A07, S20, S21 e L13.

**Acceptance Scenarios**:

1. **Given** Ana logada, **When** cria o grupo com um nome de 1 a 60 caracteres, **Then** o grupo nasce com um código de convite e Ana como única admin (G01).
2. **Given** um nome vazio ou longo demais, **When** Ana tenta criar, **Then** o servidor recusa com `INVALID_INPUT` e nada é criado (G02, S20).
3. **Given** uma foto escolhida, **When** o grupo é criado, **Then** a foto vai para a pasta do grupo e é gravada depois da criação; se o envio falhar, o grupo existe do mesmo jeito (S21, A07).

---

### User Story 2 - Pedir para entrar com o código e ser aprovado (Priority: P1)

Diego recebe o código `VoleiQuinta1`, vê a prévia do grupo e pede para entrar. Ana aprova ou recusa em Solicitações.

**Regras:** RF16, RF17, RF89 (evento), RN12, RN107 (exceção 2). **Contratos:** `request_group_join`, `decide_join_request`, `preview-invite`. **Telas:** `docs/ui/telas.md`, 6.3 e 6.7. **Textos:** `docs/copy.md`, 7.3 e 7.5.

**Why this priority**: é o centro do "Pronto quando": "uma pessoa cria o grupo, outra solicita a entrada pelo código e um admin aprova".

**Independent Test**: fluxo L12 no emulador. No servidor, G11 a G18, Q01 a Q07, C13 e C15.

**Acceptance Scenarios**:

1. **Given** um código válido, **When** Diego o informa, **Then** vê o nome e a foto do grupo, e se já é membro ou já tem pedido pendente (Q01 a Q03, Q06).
2. **Given** um código errado, de outra caixa, desativado ou de grupo excluído, **When** Diego o usa, **Then** recebe `INVITE_INVALID` (G14, Q04).
3. **Given** Diego sem pedido, **When** pede para entrar, **Then** a solicitação fica pendente e cada admin é avisado; um segundo pedido recebe `JOIN_REQUEST_PENDING`, mesmo em chamadas simultâneas (G11, G12, C13).
4. **Given** o pedido pendente, **When** Ana aprova, **Then** Diego vira membro e é avisado; **When** Ana recusa, **Then** Diego é avisado e pode pedir de novo (G15, G16).
5. **Given** um pedido já decidido, **When** outro admin decide, **Then** recebe `REQUEST_NOT_PENDING`, mesmo em decisões simultâneas (G17, C15).
6. **Given** um membro comum ou outra pessoa, **When** tenta decidir, **Then** não vê a solicitação (G18).

---

### User Story 3 - Compartilhar, regenerar e desativar o convite (Priority: P2)

Todo membro vê, copia e compartilha o código. Só os admins geram um código novo, que invalida o anterior, ou desativam o convite.

**Regras:** RF15, RN11. **Contratos:** `regenerate_group_invite`, `invalidate_group_invite`. **Telas:** `docs/ui/telas.md`, 6.5. **Textos:** `docs/copy.md`, 7.4.

**Why this priority**: o código já nasce com o grupo; regenerar e desativar protegem o grupo de um código vazado. É um item do "Pronto quando" ("o código regenerado invalida o anterior").

**Independent Test**: G07 a G10, S27, S28, L13 e M05.

**Acceptance Scenarios**:

1. **Given** Ana admin, **When** gera um código novo, **Then** o antigo deixa de valer e as solicitações já feitas continuam (G07, G08).
2. **Given** o convite desativado, **When** alguém usa o código antigo, **Then** recebe `INVITE_INVALID`, até um admin gerar outro (G09).
3. **Given** Bruno membro, **When** tenta regenerar ou desativar, **Then** recebe `NOT_GROUP_ADMIN` (G10).

---

### User Story 4 - Ver e administrar os integrantes (Priority: P2)

Os membros veem quem está no grupo. Os admins promovem, rebaixam e removem; qualquer membro sai do grupo. O grupo nunca fica sem admin.

**Regras:** RF19, RF20, RF21, RF23, RF24, RF25, RF104 (evento), RN10, RN13. **Contratos:** `set_group_role`, `leave_group`, `remove_group_member`. **Telas:** `docs/ui/telas.md`, 6.1, 6.4 e 6.6. **Textos:** `docs/copy.md`, 7.1, 7.4 e 7.5.

**Why this priority**: é o "administra os membros" do objetivo, e o RN13 é um item do "Pronto quando".

**Independent Test**: G19 a G29, C14, S19, S25, S26, S29 a S31, L14.

**Acceptance Scenarios**:

1. **Given** Ana admin, **When** promove Bruno e Bruno a rebaixa, **Then** Bruno fica como único admin (G19).
2. **Given** Ana única admin, **When** tenta se rebaixar ou sair, **Then** recebe `LAST_ADMIN`; sendo a única integrante, também (G20, G24, G25).
3. **Given** dois admins que rebaixam um ao outro ao mesmo tempo, **When** as duas chamadas chegam, **Then** uma vale e a outra recebe `LAST_ADMIN` (C14).
4. **Given** Ana admin, **When** remove Bruno, **Then** Bruno sai e é avisado; Ana não remove a si mesma (G27, G29).
5. **Given** Bruno membro, **When** sai do grupo, **Then** deixa de ver o grupo e os integrantes (G23, K03).

---

### User Story 5 - Ver o perfil de outra pessoa só com contexto (Priority: P2)

Os integrantes de um grupo veem o nome, o apelido e a foto uns dos outros. Quem não compartilha contexto não vê nada. O admin vê quem pediu para entrar enquanto o pedido está pendente.

**Regras:** RN107 e a exceção 2, RF19. **Acesso:** `docs/rls-matriz.md`, fatia 3. **Telas:** `docs/ui/telas.md`, 6.9. **Textos:** `docs/copy.md`, 7.6.

**Why this priority**: o RLS é o que protege os dados pessoais, e o teste negativo da RN107 está no "Pronto quando".

**Independent Test**: K01 a K15, A09 a A11, A13, S34.

**Acceptance Scenarios**:

1. **Given** Ana e Bruno no mesmo grupo, **When** Bruno lê os perfis, **Then** vê a Ana; Diego, sem contexto, vê só o próprio (K07).
2. **Given** um jogo passado ou uma passagem pela espera em comum, **When** um lê o outro, **Then** vê (K08).
3. **Given** o pedido pendente do Diego, **When** Ana lê o perfil dele, **Then** vê; Bruno, membro comum, não; depois da recusa, nem Ana (K09, K10).
4. **Given** Bruno saiu ou o grupo foi excluído, **When** Ana lê o perfil dele, **Then** não vê (K12, K13).
5. **Given** qualquer contexto, **When** alguém lê o telefone ou a chave Pix de outro, **Then** não vê: os dados privados continuam só do dono (K14).

---

### User Story 6 - Editar e excluir o grupo (Priority: P3)

O admin troca o nome e a foto do grupo e pode excluí-lo quando não houver jogo Aberto ou Confirmado. O grupo excluído é arquivado.

**Regras:** RF18, RF103, RF104 (evento), RN17, RN106. **Contratos:** `update_group`, `archive_group`. **Telas:** `docs/ui/telas.md`, 6.8. **Textos:** `docs/copy.md`, 7.2.

**Why this priority**: completa a administração do grupo; a recusa com jogo ativo é um item do "Pronto quando".

**Independent Test**: G04 a G06, G30 a G33, A12, S33, L13.

**Acceptance Scenarios**:

1. **Given** Ana admin, **When** troca o nome e a foto, **Then** os dois ficam gravados; uma foto fora da pasta do grupo é recusada (G04, G05).
2. **Given** um jogo do grupo Aberto ou Confirmado, **When** Ana exclui, **Then** recebe `GROUP_HAS_ACTIVE_GAMES` (G31).
3. **Given** só jogos Cancelados e Concluídos, **When** Ana exclui, **Then** o grupo é arquivado: membros removidos e avisados, pedidos pendentes cancelados, convite invalidado e registro de auditoria (G30).
4. **Given** o grupo arquivado, **When** qualquer pessoa tenta lê-lo ou alterá-lo, **Then** não encontra (G33, K04).

---

### Edge Cases

Cada caso está decidido no documento citado:

- Código digitado com espaços ou com caixa diferente: o app tira os espaços e mantém a caixa (U08); o servidor compara exatamente (`contratos-api.md`, `request_group_join`).
- Pedido simultâneo da mesma pessoa, decisão simultânea de dois admins e rebaixamento cruzado: C13 a C15.
- Último admin que é o único membro: só exclui o grupo (RN13, G25).
- Falha no envio da foto depois de criar o grupo: o grupo abre do mesmo jeito (`docs/ui/telas.md`, 6.2; S21).
- Ex-membro ou não membro que abre a rota de um grupo: estado "não encontrado" (`docs/ui/telas.md`, seção 6; S26, S32, S33).
- Erros que indicam dados mudados: a tela relê (`docs/ui/telas.md`, seção 6).
- Caminho de foto que não é um UUID: negado sem erro de conversão (A13).
- Fonte do sistema em 150% em todas as telas: S35 (RNF05).
- `anon` não lê nada (K15).

## Requirements *(mandatory)*

### Functional Requirements

Os requisitos são os de `docs/requisitos.md` e as regras, as de `docs/regras-negocio.md`. Esta lista só os liga às histórias e aos cenários de `docs/testes-referencia.md`, seção 11.

| ID | Requisito | História | Cenários |
|----|-----------|----------|----------|
| FR-001 | RF14, RN10, RN11 | 1 | G01 a G03, S20, S21, L13 |
| FR-002 | RF15, RN11 | 3 | G07 a G10, S27, S28, L13, M05 |
| FR-003 | RF16, RN12 | 2 | G11 a G14, Q01 a Q07, C13, S22 a S24, L12 |
| FR-004 | RF17, RN12 | 2 | G15 a G18, C15, S32, L12 |
| FR-005 | RF18, RN106 | 1, 6 | G04 a G06, A07, A08, A12, A13, S33 |
| FR-006 | RF19 | 4, 5 | K02, K07, S29, S30, L12 |
| FR-007 | RF20, RF104 | 4 | G27 a G29, S31 |
| FR-008 | RF21 | 4 | G23, G26, K03, S26, L12 |
| FR-009 | RF23, RN10 | 4 | G19, G21, G22, S29, S31, L14 |
| FR-010 | RF24, RN13 | 4 | G20, G24, G25, C14, S26, S31 |
| FR-011 | RF25 | 4 | K01, S18, S19 |
| FR-012 | RF103, RN17, RF104 | 6 | G30 a G33, K04, S33, L13 |
| FR-013 | RN107 e exceção 2 (`docs/rls-matriz.md`, fatia 3) | 5 | K01 a K15, A09 a A11, S34 |
| FR-014 | Eventos `group_join_requested`, `group_join_decided`, `removed_from_group` com os dados da seção 3 do `contratos-api.md` (RF89 e RF104 entregues na fatia 7) | 2, 4, 6 | G11, G15, G16, G27, G30 |
| FR-015 | Listas esperadas de políticas, privilégios e funções (`docs/rls-matriz.md`, fatia 3) | Todas | B03, B04, B06, B08, B10 |
| FR-016 | Erros convertidos em texto do catálogo (`docs/copy.md`, 7.7) | Todas | E13, E14 |

### Key Entities

Definidas em `docs/modelo-dados.md`, 4.2 e seção 7. Nenhuma tabela nova nesta fatia: todas nasceram na fatia 1.

- **Grupo (`groups`)**: nome, foto, código de convite e o arquivamento.
- **Integrante (`group_members`)**: a pessoa, o papel (admin ou membro) e a entrada.
- **Solicitação (`group_join_requests`)**: quem pediu, o status e quem decidiu.
- **Foto do grupo**: arquivo no bucket `avatars`, na pasta do grupo.
- **Prévia do convite**: dados que a `preview-invite` devolve a quem tem o código (`docs/contratos-api.md`, seção 8).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Os cinco itens de "Pronto quando" da fatia 3 (`docs/plano-implementacao.md`) são conferidos, cada um com o seu cenário.
- **SC-002**: Todos os cenários automáticos da seção 11 de `docs/testes-referencia.md` passam, e nenhum resultado esperado foi alterado.
- **SC-003**: Os cenários de concorrência C13 a C15 dão o resultado esperado em 50 de 50 repetições.
- **SC-004**: Nenhuma pessoa lê grupo, integrante, solicitação, perfil ou foto sem o papel ou o contexto da `docs/rls-matriz.md` (fatia 3): todos os casos negativos têm teste que passa.
- **SC-005**: Diego vai do código à entrada aprovada, e o grupo aparece na lista dele, no fluxo L12, sem ajuda.
- **SC-006**: Todas as telas da seção 6 do `docs/ui/telas.md` funcionam com a fonte do sistema em 150%, sem nada cortado (S35), sem texto fora do catálogo e sem cor fora do tema.

## Assumptions

- A documentação da fatia 3 foi aprovada e entrou na `main` em 15/11/2026, e os PNGs obrigatórios estão em `docs/ui/referencias/fatia-3/` (sessão 1 e etapa 2b).
- A fatia 2 está concluída: conta, perfil, termos e o acesso à própria linha.
- **Fora de escopo** (`docs/plano-implementacao.md`, fatia 3): abrir o convite por link (fatia 8), efeitos da saída do grupo sobre jogos (RF22, RF102, RN14, RN16, fatia 4: `games_left` volta vazio), os jogos no detalhe do grupo (fatia 4) e o texto final e o push das notificações (fatia 7).
- O seed ganha os grupos Vôlei de Quinta e Vôlei de Domingo da `docs/setup.md`, seção 8.
- A conferência manual M05 (compartilhar no WhatsApp) é feita na sessão 4.
