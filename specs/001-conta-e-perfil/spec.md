# Feature Specification: Conta e perfil (fatia 2)

**Feature Branch**: `fatia-2/conta-e-perfil` (o *branch* numérico do Spec Kit não é usado, `docs/trabalho-com-agente.md`, seção 3)

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Fatia 2 — Conta e perfil. A pessoa cria a conta (e-mail e senha com código de 6 dígitos, ou Google), entra, aceita os Termos de Uso e a Política de Privacidade e cuida do próprio perfil (nome, apelido, foto, telefone e visibilidade, chave Pix, troca de e-mail e de senha, sair)."

> **Como ler.** Este documento **cita** os requisitos, as regras e as seções de `docs/`, sem copiar o texto (constituição, princípio I). Em caso de divergência, vale o documento citado. Escopo, "Pronto quando" e "Fora de escopo": `docs/plano-implementacao.md`, seção 3, Fatia 2.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Criar a conta com e-mail e confirmar por código (Priority: P1)

Uma pessoa nova informa nome, e-mail e senha, recebe um código de 6 dígitos por e-mail, digita o código e fica dentro do app.

**Regras:** RF01, RF02, RF04, RF05, ADR 0017. **Telas:** `docs/ui/telas.md`, 5.1 a 5.3. **Textos:** `docs/copy.md`, 6.1 a 6.3, 6.8 e 6.9.

**Why this priority**: sem conta não há nenhum outro fluxo. É o primeiro item do "Pronto quando" da fatia.

**Independent Test**: com o Supabase local, criar uma conta com um e-mail novo, ler o código no Mailpit e confirmar. Cenários S01 a S06 e L08 de `docs/testes-referencia.md`, seção 10.4.

**Acceptance Scenarios**:

1. **Given** a tela de cadastro com os campos vazios, **When** a pessoa toca em Criar conta, **Then** cada campo mostra o seu erro e o servidor não é chamado (S01).
2. **Given** um cadastro aceito, **When** o app troca de tela, **Then** a confirmação mostra o e-mail na frase e o voltar não retorna ao cadastro (S02).
3. **Given** a tela de confirmação, **When** a pessoa digita o sexto dígito, **Then** o código é conferido sem tocar no botão, e um código errado ou vencido limpa o campo e mostra o erro nele (S03).
4. **Given** um código recém-enviado, **When** passam 60 segundos, **Then** o Reenviar código sai da contagem e volta a ficar habilitado (S04).
5. **Given** um e-mail ainda não confirmado, **When** a pessoa tenta entrar e toca em Confirmar no aviso, **Then** um código novo é pedido e a confirmação abre (S06).
6. **Given** a rota de confirmação sem e-mail em memória, **When** ela é aberta, **Then** o app vai para o login (S05).

---

### User Story 2 - Aceitar os termos na versão vigente (Priority: P1)

Logo depois do primeiro acesso, por qualquer forma de entrada, a pessoa aceita os Termos de Uso e a Política de Privacidade. O aceite volta a ser pedido quando a versão de algum documento muda.

**Regras:** RF105. **Telas:** `docs/ui/telas.md`, 3.1, 5.5 e 5.6. **Acesso:** `docs/rls-matriz.md`, fatia 2; `docs/contratos-api.md`, seção 9 (`current_terms_versions()`). **Textos:** `docs/copy.md`, 6.5.

**Why this priority**: o aceite é a porta entre o login e o resto do app, e é um item do "Pronto quando".

**Independent Test**: uma conta sem aceite cai na tela de aceite; depois de aceitar, chega à aba Jogos. Cenários P10 a P14, S09 e S10.

**Acceptance Scenarios**:

1. **Given** uma sessão sem aceite, **When** o app abre, **Then** a pessoa vai para o aceite, com a frase de primeiro aceite (S09, S10).
2. **Given** a caixa desmarcada, **When** a tela abre, **Then** o botão de aceitar está desabilitado até a caixa ser marcada (S09).
3. **Given** a caixa marcada, **When** a pessoa aceita, **Then** fica gravada uma linha por documento que faltava, com o instante do servidor, e o app vai para a aba Jogos (S09, P11).
4. **Given** um aceite da versão anterior, **When** a versão vigente muda, **Then** o aceite é pedido de novo, com a frase de documento atualizado (S10).
5. **Given** uma versão que não é a vigente, ou o aceite em nome de outra pessoa, **When** o aceite é enviado, **Then** o servidor recusa (P12).

---

### User Story 3 - Entrar com Google e vincular as duas formas de acesso (Priority: P2)

A pessoa toca em Continuar com Google, escolhe a conta e entra. Se ainda não tem conta, ela é criada com o nome do Google. Se o e-mail do Google já é de uma conta, as duas formas de acesso ficam na mesma conta.

**Regras:** RF03, RF108. **Telas:** `docs/ui/telas.md`, 5.1. **Textos:** `docs/copy.md`, 6.1 e 6.8.

**Why this priority**: é a segunda forma de entrada. Depende de conta Google real, por isso parte da conferência é manual.

**Independent Test**: no app, o seletor fechado não mostra nada e a falha mostra o aviso (S07, E12). No emulador com conta Google, M01 e M02.

**Acceptance Scenarios**:

1. **Given** o login, **When** a pessoa fecha o seletor do Google sem escolher, **Then** nada acontece, sem mensagem (S07, E12).
2. **Given** uma falha do Google, **When** ela ocorre, **Then** aparece o aviso próprio do Google (S07).
3. **Given** uma conta nova pelo Google, **When** a entrada conclui, **Then** o perfil nasce com o nome do Google e o aceite dos termos aparece (M01).
4. **Given** uma conta criada por e-mail e senha, **When** a pessoa entra pelo Google com o mesmo e-mail, **Then** entra na mesma conta, sem criar outra (M02).

---

### User Story 4 - Ver o perfil e sair (Priority: P2)

Na aba Perfil, a pessoa vê a foto ou as iniciais, o nome exibido, o e-mail e os caminhos para cada edição, e pode sair da conta.

**Regras:** RF07, RN100. **Telas:** `docs/ui/telas.md`, 5.7. **Textos:** `docs/copy.md`, 6.6.

**Why this priority**: é a porta de entrada das edições e substitui a aba provisória da fatia 1.

**Independent Test**: abrir a aba Perfil com contas de tipos diferentes. Cenários P01, S11 e S17.

**Acceptance Scenarios**:

1. **Given** um perfil com nome e apelido, **When** a aba abre, **Then** o cabeçalho mostra o apelido (S17).
2. **Given** uma conta que entrou só pelo Google, **When** a aba abre, **Then** não aparecem Trocar e-mail nem Trocar senha, e as rotas delas voltam ao perfil (S11).
3. **Given** a pessoa logada, **When** toca em Sair, **Then** a sessão termina sem confirmação e o app volta ao login.
4. **Given** duas pessoas com perfil, **When** uma lê os perfis, **Then** vê só o próprio (P01, P08, P13).

---

### User Story 5 - Editar nome, apelido, foto e telefone (Priority: P2)

A pessoa edita os próprios dados e grava tudo de uma vez.

**Regras:** RF08, RF09, RF10, RF12, RN100, RN101, RN106. **Telas:** `docs/ui/telas.md`, 5.8. **Acesso:** `docs/rls-matriz.md`, fatia 2 (tabelas e bucket `avatars`).

**Why this priority**: o apelido e a foto são o que os outros veem nas listas das próximas fatias.

**Independent Test**: editar e salvar, e reabrir o perfil. Cenários P02 a P09, P15, P16, A01 a A06, S12, U03, U04 e L10.

**Acceptance Scenarios**:

1. **Given** o telefone vazio, **When** a tela abre, **Then** o interruptor de mostrar o telefone está desabilitado; apagar o telefone o desliga (S12).
2. **Given** um telefone incompleto, **When** a pessoa salva, **Then** o campo mostra o erro (S12).
3. **Given** uma foto nova no lugar da antiga, **When** a pessoa salva, **Then** as gravações acontecem na ordem do `telas.md`, 5.8 (S12).
4. **Given** um apelido apagado, **When** a pessoa salva, **Then** o nome exibido volta a ser o nome (P02).
5. **Given** uma foto acima de 2 MB ou fora dos tipos aceitos, **When** ela é enviada, **Then** o servidor recusa (A02, A04).
6. **Given** outra pessoa, **When** ela tenta ler, editar ou enviar arquivo na pasta de alguém, **Then** o servidor recusa (P03, P05, P15, P16, A05, A06).

---

### User Story 6 - Cadastrar, trocar e remover a chave Pix (Priority: P2)

A pessoa escolhe o tipo, informa a chave e salva. Pode trocar quando quiser e só não pode remover enquanto for recebedora de algo em aberto.

**Regras:** RF11, RF12, RN105. **Telas:** `docs/ui/telas.md`, 5.9. **Dados:** `docs/modelo-dados.md`, 4.1 (formatos e dígitos verificadores).

**Why this priority**: a chave Pix é pré-requisito do recebedor nas fatias 4 a 6, e o teste da RN105 é um item do "Pronto quando".

**Independent Test**: salvar chaves válidas e inválidas de cada tipo, e tentar remover em cada situação da RN105. Cenários X01 a X10, N01 a N09, S13, U01, U02, U05 e U06.

**Acceptance Scenarios**:

1. **Given** uma chave inválida para o tipo, **When** a pessoa salva, **Then** o campo mostra o erro e o servidor não é chamado (S13).
2. **Given** um tipo escolhido, **When** a pessoa troca o tipo, **Then** o campo é limpo (S13).
3. **Given** a pessoa é recebedora de um jogo em aberto ou tem valor a receber em aberto, **When** remove a chave, **Then** a remoção é recusada e a chave continua (N01, N02, N04, N05, S13).
4. **Given** a mesma situação, **When** a pessoa troca a chave por outra válida, **Then** a troca é aceita (N07).
5. **Given** uma chave fora do formato, **When** ela é gravada direto no banco, **Then** o banco recusa (X01 a X10).

---

### User Story 7 - Recuperar a senha esquecida (Priority: P3)

A pessoa informa o e-mail, recebe um código, digita o código e a senha nova, e entra.

**Regras:** RF06, ADR 0017. **Telas:** `docs/ui/telas.md`, 5.4. **Textos:** `docs/copy.md`, 6.4.

**Why this priority**: caminho de recuperação, usado poucas vezes.

**Independent Test**: recuperar a senha de uma conta do seed com o código do Mailpit. Cenários S08 e L09.

**Acceptance Scenarios**:

1. **Given** a etapa 1, **When** a pessoa envia o e-mail, **Then** o app avança para a etapa 2, exista ou não conta com aquele e-mail.
2. **Given** um código aceito e uma senha nova recusada, **When** isso acontece, **Then** a tela fica só com o campo de senha e o erro nele, e o novo toque muda só a senha (S08).
3. **Given** um código válido e uma senha válida, **When** a pessoa salva, **Then** entra no app, e a senha antiga não entra mais (L09).

---

### User Story 8 - Trocar o e-mail e a senha estando logado (Priority: P3)

Quem tem acesso por e-mail e senha troca o e-mail, com código enviado ao endereço novo, e troca a senha informando a atual.

**Regras:** RF106, RF107, ADR 0017. **Telas:** `docs/ui/telas.md`, 5.10 e 5.11. **Textos:** `docs/copy.md`, 6.7.

**Why this priority**: manutenção da conta, usada poucas vezes.

**Independent Test**: trocar o e-mail e a senha de contas do seed. Cenários S14, S15, U07 e L11.

**Acceptance Scenarios**:

1. **Given** um novo e-mail igual ao atual, **When** a pessoa envia, **Then** o campo mostra o erro e o servidor não é chamado (S14).
2. **Given** um e-mail que já é de outra conta, **When** a pessoa envia, **Then** o campo mostra o erro (S14).
3. **Given** o código do novo endereço, **When** a pessoa confirma, **Then** o e-mail novo passa a valer e o antigo não entra mais (L11).
4. **Given** a senha atual errada, **When** a pessoa salva, **Then** o erro aparece no campo Senha atual e a senha não muda (S15).

---

### Edge Cases

Cada caso está decidido no documento citado:

- E-mail que já tem conta no cadastro: `docs/ui/telas.md`, 5.2.
- App reaberto no meio da confirmação: `docs/ui/telas.md`, 5.3 (S05).
- Versão dos termos mudando entre abrir a tela e aceitar: `docs/ui/telas.md`, 5.5.
- Falha ou falta de conexão na conferência dos termos: `docs/ui/telas.md`, 3.1.
- Erro depois de enviar a foto, e falha ao apagar a foto antiga: `docs/ui/telas.md`, 5.8.
- Código válido com senha nova recusada na recuperação: `docs/ui/telas.md`, 5.4 (S08).
- Sessão invalidada e falta de conexão: `docs/ui/telas.md`, 3.1 (RNF07).
- Fonte do sistema em 150% em todas as telas: S16 (RNF05).
- Remoção da chave Pix em cada situação da RN105: N01 a N09.
- Quem não tem `login`: `anon` não lê nada (P14).

## Requirements *(mandatory)*

### Functional Requirements

Os requisitos são os de `docs/requisitos.md` e as regras, as de `docs/regras-negocio.md`. Esta lista só os liga às histórias e aos cenários.

| ID | Requisito | História | Cenários (`testes-referencia.md`, seção 10) |
|----|-----------|----------|---------------------------------------------|
| FR-001 | RF01 | 1 | S01, S02, L08 |
| FR-002 | RF02 | 1 | S03 a S06, L08 |
| FR-003 | RF03 | 3 | S07, E12, M01 |
| FR-004 | RF04 | 1 | L01 a L07 (fatia 1), S06 |
| FR-005 | RF05 | 1 | L05 (fatia 1), S10 |
| FR-006 | RF06 | 7 | S08, L09 |
| FR-007 | RF07 | 4 | L07 (fatia 1), S11 |
| FR-008 | RF08, RN100 | 4, 5 | P02, S17, L10 |
| FR-009 | RF09, RN106 | 5 | P05, P15, P16, A01 a A06, S12 |
| FR-010 | RF10, RN101 | 5 | P08, S12, U03, U04, L10 |
| FR-011 | RF11 | 6 | X01 a X10, S13, U01, U02, U05, U06 |
| FR-012 | RF12, RN105 | 5, 6 | N01 a N09, S12, S13 |
| FR-013 | RF105 | 2 | P10 a P13, S09, S10, L08 |
| FR-014 | RF106 | 8 | S14, L11 |
| FR-015 | RF107 | 8 | S15, U07 |
| FR-016 | RF108 | 3 | M02 |
| FR-017 | Acesso só à própria linha e às próprias fotos (`docs/rls-matriz.md`, fatia 2) | 4, 5 | P01 a P16, B03, B04, B06, B10 |
| FR-018 | Erros convertidos em texto do catálogo (`docs/copy.md`, 6.8) | Todas | E09 a E12 |
| FR-019 | E-mails de conta com código, pelos modelos do `docs/copy.md`, 6.9 | 1, 7, 8 | L08, L09, L11, M03 |

### Key Entities

Definidas em `docs/modelo-dados.md`, 4.1 e seção 7. Nenhuma tabela nova nesta fatia.

- **Perfil (`profiles`)**: nome, apelido, nome exibido e foto.
- **Dados privados (`profile_private`)**: telefone, visibilidade do telefone e chave Pix.
- **Aceite (`terms_acceptances`)**: documento, versão e instante do aceite.
- **Versão vigente dos termos**: devolvida por `current_terms_versions()` (`docs/contratos-api.md`, seção 9).
- **Foto de perfil**: arquivo no bucket `avatars`, na pasta da pessoa.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Os cinco itens de "Pronto quando" da fatia 2 (`docs/plano-implementacao.md`) são conferidos, cada um com o seu cenário ou a sua conferência manual.
- **SC-002**: Todos os cenários automáticos da seção 10 de `docs/testes-referencia.md` passam, e nenhum resultado esperado foi alterado.
- **SC-003**: Uma pessoa nova vai do cadastro à aba Jogos, com código e aceite, no fluxo L08, sem ajuda.
- **SC-004**: Nenhuma pessoa lê nem altera dados, aceites ou fotos de outra: todos os casos negativos da `docs/rls-matriz.md` (fatia 2) têm teste que passa.
- **SC-005**: Todas as telas da seção 5 do `docs/ui/telas.md` funcionam com a fonte do sistema em 150%, sem nada cortado (S16).
- **SC-006**: Nenhum texto de interface fora do catálogo (`docs/copy.md`, seção 6) e nenhuma cor fora do tema.

## Assumptions

- A documentação da fatia 2 foi aprovada no PR #2 (12/11/2026), com os PNGs obrigatórios em `docs/ui/referencias/fatia-2/`. A conferência dos PNGs está em `docs/ui/referencias/README.md`.
- A fatia 1 está concluída: banco completo, RLS ativado sem políticas, login técnico e CI.
- **Fora de escopo** (`docs/plano-implementacao.md`, fatia 2): excluir conta (RF13, fatia 6), telefone visível para outros (RF101, fatia 4), remoção do token de push no logout (fatia 7) e leitura do perfil de outra pessoa (RN107, fatia 3).
- As abas Jogos, Grupos e Cobranças continuam com o estado provisório da fatia 1.
- O texto jurídico dos documentos é provisório até o lançamento (`docs/ui/telas.md`, 5.6).
- **Conferência manual:** M01 a M04 dependem de conta Google real, do Resend e da produção, e são feitas pelo responsável (`docs/trabalho-com-agente.md`, seção 7).
