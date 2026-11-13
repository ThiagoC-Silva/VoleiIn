# Especificação: Fatia 2 — Conta e perfil

**Branch**: `fatia-2/conta-e-perfil` (o *branch* numérico do Spec Kit não é usado, `docs/trabalho-com-agente.md`, seção 3)

**Criada**: 2026-11-12

**Status**: Rascunho

**Entrada**: Fatia 2 do `docs/plano-implementacao.md` (seção 3). RFs: RF01 a RF12, RF105 a RF108. RNs: RN100, RN105, RN106.

> Esta especificação **cita** os documentos e não copia o texto deles. `docs/` é a fonte da verdade (constituição, princípio I). Em caso de divergência, vale o documento citado.

| Assunto | Fonte |
|---------|-------|
| Requisitos | `docs/requisitos.md`, seção 1 |
| Regras | `docs/regras-negocio.md`, seção 10 (RN100, RN105, RN106) e seção 2 (RN01, RN02) |
| Telas e navegação | `docs/ui/telas.md`, seções 3 e 5 |
| Aparência | `docs/ui/referencias/fatia-2/*.png` e a conferência em `docs/ui/referencias/README.md` |
| Textos e erros | `docs/copy.md`, seção 6 |
| Banco | `docs/modelo-dados.md`, seção 4.1 e seção 7 |
| Acesso (RLS e Storage) | `docs/rls-matriz.md`, "Fatia 2" |
| Contratos | `docs/contratos-api.md`, seção 2 (`PIX_KEY_IN_USE`) e seção 9 (escritas diretas e `current_terms_versions()`) |
| Cenários de teste | `docs/testes-referencia.md`, seção 10 (P, X, N, A, U, E, S, L, M) e as listas B03, B04, B06 e B10 da seção 9.1 |
| Auth por código | ADR 0017 e `docs/setup.md`, seção 6 |

## Cenários de uso e testes *(obrigatório)*

### História 1 — Criar a conta por e-mail e confirmar com o código (Prioridade: P1)

Uma pessoa sem conta se cadastra com nome, e-mail e senha, recebe um código de 6 dígitos no e-mail, digita o código e entra no app (RF01, RF02, RF04, RF05; `telas.md` 5.2 e 5.3).

**Por que esta prioridade**: sem conta, nenhuma outra função do app existe.

**Teste independente**: cenário L08 (`testes-referencia.md`, 10.4), do cadastro até a aba Jogos, com o código lido do Mailpit.

**Cenários de aceite**:

1. **Dado** o cadastro com campos vazios ou senha curta, **quando** a pessoa toca em Criar conta, **então** os erros aparecem nos campos e nada é enviado (S01).
2. **Dado** o cadastro aceito, **quando** a tela de confirmação abre, **então** mostra o e-mail e o voltar não retorna ao cadastro (S02).
3. **Dado** a tela de confirmação, **quando** o sexto dígito é digitado, **então** a confirmação começa sozinha; código errado mostra o erro no campo e o limpa (S03).
4. **Dado** um envio de código, **quando** passam 60 s, **então** o Reenviar código volta a ficar habilitado (S04).
5. **Dado** o app reaberto na confirmação sem e-mail em memória, **então** a pessoa vai ao login (S05); ao entrar com e-mail não confirmado, a ação Confirmar pede um código novo e volta à confirmação (S06).
6. **Dado** um cadastro confirmado, **então** o perfil nasce com o nome informado, sem perfil para cadastros nunca confirmados (`modelo-dados.md`, 4.1; B15 a B23 já cobertos na fatia 1).

---

### História 2 — Aceitar os termos (Prioridade: P1)

Toda pessoa logada aceita os Termos de Uso e a Política de Privacidade na versão vigente antes de usar o app, e aceita de novo quando uma versão muda (RF105; `telas.md` 3.1 e 5.5).

**Por que esta prioridade**: é condição legal de uso e porteiro de todas as outras telas.

**Teste independente**: S09 e S10 (widget), P10 a P13 (pgTAP) e o fim do L08.

**Cenários de aceite**:

1. **Dado** uma sessão sem aceite, **então** o app abre a tela de aceite, com o botão desabilitado até a caixa ser marcada; ao aceitar, grava um aceite por documento que falta e vai para a aba Jogos (S09, S10).
2. **Dado** a versão vigente diferente da aceita, **então** a tela volta com a frase de documentos atualizados (S10).
3. **Dado** uma tentativa de aceite de versão que não é a vigente, ou em nome de outra pessoa, **então** o servidor recusa (P12).
4. **Dado** um aceite gravado, **então** o instante é o do servidor, e o app não consegue informá-lo (P11, RN02).

---

### História 3 — Entrar e sair (Prioridade: P1)

A pessoa entra com e-mail e senha ou com o Google, continua logada nas próximas aberturas e pode sair (RF03, RF04, RF05, RF07, RF108; `telas.md` 5.1 e 5.7).

**Por que esta prioridade**: completa o acesso para quem já tem conta e para quem prefere o Google.

**Teste independente**: S06, S07 (widget); M01 e M02 (conferência manual com conta Google real).

**Cenários de aceite**:

1. **Dado** o seletor do Google fechado sem escolha, **então** nada acontece; uma falha do Google mostra o aviso próprio (S07, E12).
2. **Dado** uma conta nova pelo Google, **então** o perfil nasce com o nome do Google e o aceite dos termos aparece (M01).
3. **Dado** o Google com o e-mail de uma conta de e-mail e senha, **então** entra na mesma conta, sem criar outra, e as opções de trocar e-mail e senha continuam visíveis (M02, RF108).
4. **Dado** a pessoa logada, **quando** toca em Sair, **então** volta ao login, e o seletor do Google aparece de novo na próxima entrada (`telas.md` 5.7).

---

### História 4 — Recuperar a senha esquecida (Prioridade: P2)

A pessoa pede um código pelo e-mail, digita o código e uma senha nova, e entra (RF06; `telas.md` 5.4).

**Por que esta prioridade**: sem ela, quem esquece a senha perde a conta, mas o app funciona sem ela no primeiro uso.

**Teste independente**: S08 (widget) e L09 (integração).

**Cenários de aceite**:

1. **Dado** um e-mail informado, **então** o app sempre avança para a etapa do código, com ou sem conta para esse e-mail.
2. **Dado** o código válido e a senha nova recusada, **então** a tela fica só com o campo de senha e o novo toque não pede o código de novo (S08).
3. **Dado** a senha trocada, **então** a senha antiga não entra mais (L09).

---

### História 5 — Cuidar do próprio perfil (Prioridade: P2)

A pessoa vê o próprio perfil e edita nome, apelido, foto, telefone e a visibilidade do telefone (RF08, RF09, RF10, RF12, RN100, RN106; `telas.md` 5.7 e 5.8).

**Por que esta prioridade**: o nome exibido e a foto aparecem em todas as listas das fatias seguintes.

**Teste independente**: S11, S12, S17 (widget), P01 a P09 e P15, P16 (pgTAP), A01 a A06 (Deno), L10 (integração).

**Cenários de aceite**:

1. **Dado** um apelido, **então** o perfil mostra o apelido; sem ele, o nome (S17, P02, RN100).
2. **Dado** o telefone vazio, **então** o interruptor de visibilidade fica desabilitado; apagar o telefone o desliga; telefone fora do formato mostra erro (S12, RN101).
3. **Dado** uma foto nova no lugar da antiga, **quando** a pessoa salva, **então** a ordem é: enviar a foto nova, gravar o perfil, gravar os dados privados, apagar a antiga (S12).
4. **Dado** uma foto acima de 2 MB ou fora de JPEG, PNG e WebP, **então** o servidor recusa e o app mostra o aviso (A02 a A04, E11, RN106).
5. **Dado** outra pessoa, **então** ninguém lê nem edita o perfil, os dados privados, os aceites ou as fotos de outra pessoa (P01, P03, P08, P13, P15, P16, A05, A06).
6. **Dado** uma conta só com Google, **então** o perfil não mostra Trocar e-mail e Trocar senha, nem pela rota (S11).

---

### História 6 — Cadastrar, trocar e remover a chave Pix (Prioridade: P2)

A pessoa cadastra a chave Pix por tipo, troca quando quiser e remove quando não estiver comprometida com jogos ou valores a receber (RF11, RF12, RN105; `telas.md` 5.9).

**Por que esta prioridade**: a chave é pré-requisito para ser recebedor (fatia 4), e a regra de remoção protege os pagadores.

**Teste independente**: X01 a X10, N01 a N09 (pgTAP), U01, U02, U05, U06 (unitários), S13 (widget).

**Cenários de aceite**:

1. **Dado** um CPF ou CNPJ com dígito verificador errado ou sequência repetida, **então** o app avisa no campo, e o banco recusa se o app falhar (U01, U02, X01 a X06, S13).
2. **Dado** a pessoa recebedora de um jogo Aberto ou Confirmado, ou com valor a receber Pendente ou Em análise, **quando** remove a chave, **então** a remoção é recusada e a chave continua (N01, N02, N04, N05, S13).
3. **Dado** o mesmo caso, **quando** troca a chave por outra válida, **então** a troca é aceita (N07).

---

### História 7 — Trocar e-mail e senha logado (Prioridade: P3)

Quem tem acesso por e-mail e senha troca o e-mail, com código no endereço novo, e troca a senha informando a atual (RF106, RF107; `telas.md` 5.10 e 5.11).

**Por que esta prioridade**: manutenção da conta, sem impacto nas fatias seguintes.

**Teste independente**: S14, S15 (widget), L11 (integração).

**Cenários de aceite**:

1. **Dado** o novo e-mail igual ao atual, **então** erro no campo sem chamar o servidor; e-mail de outra conta, erro no campo (S14).
2. **Dado** o código confirmado, **então** o e-mail novo passa a valer, e o antigo deixa de entrar (L11). Até a confirmação, o antigo continua valendo (RF106).
3. **Dado** a senha atual errada, **então** erro no campo Senha atual e a senha não muda (S15).

---

### Casos de borda

- E-mail que já tem conta no cadastro: o app segue para a confirmação, sem revelar que a conta existe, e a frase de ajuda orienta (`telas.md` 5.2, 5.3).
- Versão dos termos trocada entre abrir a tela e aceitar: o servidor recusa, o app relê as versões e mostra a tela de novo (`telas.md` 5.5).
- Erro depois de enviar a foto: nada mais é gravado, e a foto sem uso fica para a limpeza da fatia 6 (`telas.md` 5.8).
- Falha ao apagar a foto antiga: ignorada, porque o perfil já está salvo (`telas.md` 5.8).
- Perfil anonimizado (`deleted_at` preenchido): a própria pessoa não edita mais o perfil (P06).
- Sem conexão: as telas mostram o estado sem conexão; as ações mostram o aviso e preservam os campos (`design-system.md`, 7.16; `arquitetura-app.md`, seção 7).
- Fonte do sistema em 150%: nenhuma tela quebra (S16, RNF05).

## Requisitos *(obrigatório)*

### Requisitos funcionais

Cada item aponta para a regra de origem. O comportamento detalhado está no documento citado.

- **FR-001**: Cadastro por e-mail e senha com nome obrigatório (RF01), com a validação local de `telas.md` 5 ("Regras comuns").
- **FR-002**: Confirmação do e-mail por código de 6 dígitos antes do primeiro acesso (RF02, ADR 0017), com reenvio limitado a um a cada 60 s na tela.
- **FR-003**: Entrada e cadastro pelo Google, com o nome vindo da conta Google (RF03), e vinculação ao cadastro por e-mail com o mesmo e-mail verificado (RF108).
- **FR-004**: Entrada por e-mail e senha (RF04) e sessão mantida entre aberturas (RF05). Falta de conexão não encerra a sessão (RNF07).
- **FR-005**: Recuperação de senha por código (RF06), em duas etapas na mesma tela (`telas.md` 5.4).
- **FR-006**: Saída da conta, encerrando também a sessão do Google (RF07).
- **FR-007**: Apelido opcional; o nome exibido é o apelido ou, sem ele, o nome (RF08, RN100).
- **FR-008**: Foto de perfil em JPEG, PNG ou WebP, redimensionada no app para até 1024 px e recusada pelo servidor acima de 2 MB ou fora do tipo (RF09, RN106).
- **FR-009**: Telefone opcional do Brasil e a escolha de visibilidade, oculta por padrão (RF10, RN101). A exibição a terceiros fica para a fatia 4 (RF101).
- **FR-010**: Chave Pix por tipo, com formato e dígitos verificadores conferidos no app e no banco (RF11, `modelo-dados.md` 4.1).
- **FR-011**: Edição de todos os dados de perfil (RF12), com a remoção da chave Pix bloqueada pelo servidor nos casos da RN105 e a troca sempre livre.
- **FR-012**: Aceite dos documentos na versão vigente ao entrar pela primeira vez e a cada mudança de versão, com versão e instante do servidor gravados (RF105, RN02).
- **FR-013**: Troca do e-mail de acesso com código enviado só ao endereço novo, mantendo o antigo até a confirmação (RF106).
- **FR-014**: Troca da senha logado, conferindo a senha atual (RF107).
- **FR-015**: Trocar e-mail e trocar senha só existem para quem tem acesso por e-mail e senha (`telas.md` 5.7, U07, S11).
- **FR-016**: Cada pessoa lê e grava só a própria linha de perfil, de dados privados e de aceites, e só as próprias fotos; sem login, nada (`rls-matriz.md`, Fatia 2; P01 a P16).
- **FR-017**: Todo erro mostrado vem do catálogo de textos (`copy.md` 5.5 e 6.8), sem texto técnico (E09 a E12).
- **FR-018**: Os e-mails de conta levam o código também no assunto e saem, na produção, pelo Resend (`copy.md` 6.9, M03).

### Entidades principais

- **Perfil** (`profiles`): nome, apelido, nome exibido derivado, caminho da foto, marca de anonimização.
- **Dados privados** (`profile_private`): telefone, visibilidade do telefone, tipo e valor da chave Pix. Só o dono lê.
- **Aceite dos termos** (`terms_acceptances`): documento, versão e instante do aceite, um por documento e versão.
- **Versão vigente dos termos**: uma versão por documento, definida no servidor e trocada por migração (`contratos-api.md`, seção 9).
- **Foto de perfil**: arquivo no armazenamento privado, na pasta da própria pessoa (`modelo-dados.md`, seção 7).

## Critérios de sucesso *(obrigatório)*

### Resultados mensuráveis

Os critérios são os de "Pronto quando" da fatia 2 (`plano-implementacao.md`) e a definição de pronto (`trabalho-com-agente.md`, seção 5).

- **SC-001**: Uma pessoa nova cria a conta por e-mail, confirma com o código e chega à aba Jogos no Supabase local e na produção sem usuários reais (L08, M04).
- **SC-002**: Entrar com o Google cria a conta ou entra na existente com o mesmo e-mail, sem duplicar (M01, M02).
- **SC-003**: Os três e-mails de conta chegam pelo Resend com o código no assunto (M03).
- **SC-004**: Mudar a versão de um documento faz todas as pessoas verem o aceite de novo na abertura seguinte (S10).
- **SC-005**: 100% das tentativas de remover a chave nos casos da RN105 são recusadas, e 100% das trocas são aceitas (N01 a N09).
- **SC-006**: 100% das fotos acima de 2 MB ou fora do tipo são recusadas pelo servidor (A02, A04).
- **SC-007**: Nenhum teste negativo de acesso encontra dado de outra pessoa (P01 a P16, A05, A06).
- **SC-008**: Todos os cenários da seção 10 do `testes-referencia.md` passam, e os comandos da definição de pronto ficam verdes.
- **SC-009**: Todas as telas da fatia funcionam com a fonte do sistema em 150% (S16, RNF05) e abrem dentro dos tempos da RNF04.

## Premissas

- A fatia 1 está concluída: banco completo, *trigger* do perfil, buckets, CI e login técnico.
- O Supabase Auth faz a vinculação do RF108 sozinho, por e-mail verificado; o app não tem código próprio para isso (`telas.md` 5.1).
- Os textos jurídicos ainda não existem; a tela do documento mostra a frase provisória (`telas.md` 5.6).
- A conferência com conta Google real e com o Resend (M01 a M04) é manual, feita pelo responsável, inclusive a configuração do painel da produção (`setup.md`, 5.2 e 6).
- **Fora de escopo** (`plano-implementacao.md`, fatia 2): excluir conta (RF13, fatia 6), telefone visível para outros (RF101, fatia 4), leitura de perfis por contexto (RN107, fatia 3) e remoção do token de push no logout (fatia 7).
