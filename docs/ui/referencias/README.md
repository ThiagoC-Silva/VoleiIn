# Referências visuais das telas

> Decisão de 12/11/2026. Nenhuma tela é implementada sem o PNG de referência do responsável.
> Fluxo: o agente escreve aqui o **briefing** de cada tela da fatia (o que ela precisa conter); o responsável desenha e salva o PNG nesta pasta; só então a tela entra no código.

## Como funciona

- **Pasta e nome:** `docs/ui/referencias/fatia-<n>/<nomeDaRota>.png`, com o nome da rota de `docs/ui/telas.md` (seção 1). Variantes e etapas levam um sufixo: `forgotPassword-etapa2.png`, `profile-google.png`.
- **Quem decide o quê:** o PNG decide a **aparência e a disposição**. O `telas.md` decide **o que a tela contém e como se comporta**, e o `docs/copy.md` decide os textos. Se o PNG não tiver um elemento do briefing, ou tiver um a mais, o agente para e pergunta antes de implementar.
- **O que não precisa desenhar:** os estados comuns já definidos no `design-system.md` (carregando, erro, sem conexão, erro no campo, `SnackBar`, botão carregando, seções 7.1, 7.2 e 7.16). Desenhe só se quiser algo diferente do padrão.
- **Base visual:** só modo escuro, cores, fontes e componentes do `design-system.md` (ADR 0013). Largura de referência: 360 dp (celular comum). Os textos do PNG podem ser aproximados: o texto final vem do `docs/copy.md`.
- **Obrigatório** no briefing: sem esse PNG, a tela não é implementada. **Opcional:** sem ele, o agente segue o `design-system.md`.

## Fatia 2. Conta e perfil

Detalhe de cada tela em `docs/ui/telas.md`, seção 5. Textos em `docs/copy.md`, seção 6.

| Arquivo | Tela | Status |
|---------|------|--------|
| `login.png` | Login, completado | Obrigatório |
| `signup.png` | Cadastro | Obrigatório |
| `confirmEmail.png` | Confirmar e-mail (código) | Obrigatório |
| `forgotPassword-etapa1.png` e `forgotPassword-etapa2.png` | Recuperar senha | Obrigatório |
| `terms.png` | Aceite dos termos | Obrigatório |
| `termsDocument.png` | Texto de um documento (provisório) | Opcional |
| `profile.png` e `profile-google.png` | Meu perfil, com e sem acesso por e-mail e senha | Obrigatório |
| `profileEdit.png` e `profileEdit-foto.png` | Editar perfil e a sheet da foto | Obrigatório |
| `profilePix.png` e `profilePix-remover.png` | Chave Pix e a confirmação de remoção | Obrigatório |
| `profilePix-tipo.png` | Chave Pix com o menu do tipo aberto | Extra, enviado pelo responsável |
| `profileEmail-etapa1.png` e `profileEmail-etapa2.png` | Trocar e-mail | Obrigatório |
| `profilePassword.png` | Trocar senha | Obrigatório |

### Conferência dos PNGs da fatia 2 (12/11/2026)

Todos os PNGs obrigatórios chegaram, com todos os elementos do briefing. Na implementação:

- **A folha da foto não tem título.** O PNG mostra "Foto do perfil", mas o responsável decidiu tirar. "Remover foto" fica em tom destrutivo e sem confirmação.
- **No título "Confirme o seu e-mail", o hífen não quebra** (U+2011). O PNG mostra a quebra "e-" / "mail", que não deve acontecer.
- O tipo da chave Pix é um menu suspenso com ícones (`profilePix-tipo.png`), e não chips.
- Os ícones decorativos (quadrado amarelo na confirmação e no aceite, ícones nas linhas, relógio no reenviar) e o bloco amarelo do login seguem os PNGs.

### `login.png`. Login (`/login`)

O login da fatia 1 continua (espaço do logo com `VoleiIn`, subtítulo, campos E-mail e Senha com o olho de mostrar a senha, botão principal Entrar). Acrescentar:

- botão de texto **Esqueci minha senha**, ligado ao campo Senha;
- divisor com **ou**;
- botão de contorno **Continuar com Google**;
- no pé, a frase **Não tem conta?** e o botão de texto **Criar conta**.

### `signup.png`. Cadastro (`/signup`)

- Barra superior interna: voltar e o título **Criar conta**.
- Frase de apoio.
- Campos **Nome**, **E-mail** e **Senha** (com o olho), e a dica **Pelo menos 8 caracteres** abaixo da senha.
- Botão principal **Criar conta**.
- No pé: **Já tem conta?** e o botão de texto **Entrar**.
- Sem caixa de aceite dos termos.

### `confirmEmail.png`. Confirmar e-mail (`/confirm-email`)

- Título **Confirme o seu e-mail**.
- A frase com o e-mail: "Enviamos um código de 6 dígitos para ana@exemplo.com."
- **Campo de código de 6 dígitos.** A forma é sua: um campo só ou seis casas.
- Botão principal **Confirmar**.
- Botão de texto **Reenviar código**, que fica desabilitado com uma contagem ("Reenviar código em 45 s"). Mostre o estado que preferir.
- Frase de ajuda em tom secundário: "Não chegou? Confira o spam. Se este e-mail já tem conta, entre ou recupere a senha."
- Botão de texto **Usar outro e-mail**.

### `forgotPassword-etapa1.png` e `-etapa2.png`. Recuperar senha (`/forgot-password`)

- Barra superior interna: voltar e o título **Recuperar senha**.
- **Etapa 1:** frase de apoio, campo **E-mail** e botão principal **Enviar código**.
- **Etapa 2:** a frase com o e-mail, o campo de código (igual ao da `confirmEmail`), o campo **Nova senha** com o olho, o botão principal **Salvar nova senha** e o **Reenviar código**.

### `terms.png`. Aceite dos termos (`/terms`)

- Sem barra inferior e sem voltar.
- Título **Antes de continuar** e frase de apoio.
- Duas linhas com seta, uma por documento: **Termos de Uso** e **Política de Privacidade**, cada uma com o subtítulo **Versão 1.0**.
- Caixa de seleção **Li e aceito os Termos de Uso e a Política de Privacidade**.
- Botão principal **Aceitar e continuar**. Mostre-o desabilitado (caixa desmarcada) ou habilitado, como preferir.
- Botão de texto **Sair**.

### `termsDocument.png`. Texto de um documento (`/terms/:document`), opcional

- Barra superior interna: voltar e o nome do documento.
- Corpo de texto rolável. Por enquanto, uma frase provisória.

### `profile.png` e `profile-google.png`. Meu perfil (`/profile`)

- Barra superior de raiz com o título **Perfil**. A barra inferior aparece, com a aba Perfil ativa.
- Cabeçalho: **avatar de 72** (foto ou iniciais sobre pastel, `design-system.md`, 3.4), o **nome exibido** (apelido ou nome) e o **e-mail** da conta.
- Lista de linhas com seta:
  - **Editar perfil**, com o subtítulo "Nome, apelido, foto e telefone";
  - **Chave Pix**, com o subtítulo "CPF · 529.982.247-25" ou "Não cadastrada";
  - **Trocar e-mail** e **Trocar senha**.
- Botão de contorno **Sair**.
- **`profile-google.png`:** a mesma tela sem as linhas Trocar e-mail e Trocar senha (conta que entrou só pelo Google).

### `profileEdit.png` e `profileEdit-foto.png`. Editar perfil (`/profile/edit`)

- Barra superior interna: voltar e o título **Editar perfil**.
- **Avatar de 96** com o botão de texto **Trocar foto**.
- Campos **Nome** e **Apelido**, este com a dica "Aparece no lugar do nome nas listas".
- Campo **Telefone** com o prefixo fixo **+55** e a máscara `(86) 99999-1234`.
- Interruptor **Mostrar meu telefone**, com a dica "Quem estiver nos seus grupos e jogos poderá ver".
- Botão principal **Salvar**.
- **`profileEdit-foto.png`:** a sheet que abre em Trocar foto, com **Escolher da galeria**, **Tirar foto** e **Remover foto**.

### `profilePix.png` e `profilePix-remover.png`. Chave Pix (`/profile/pix`)

- Barra superior interna: voltar e o título **Chave Pix**.
- Rótulo **Tipo da chave** e cinco opções: **CPF**, **CNPJ**, **E-mail**, **Telefone** e **Aleatória**. O documento sugere chips, mas a forma é sua.
- Campo **Chave**, com a máscara do tipo escolhido (no exemplo, CPF `529.982.247-25`).
- Botão principal **Salvar**.
- Botão destrutivo de contorno **Remover chave**, quando já há chave.
- **`profilePix-remover.png`:** a confirmação, com o título **Remover a chave Pix?**, a frase "Sem chave Pix, você não pode ser recebedor de jogos.", o botão destrutivo sólido **Remover** e o botão de contorno **Voltar** (`design-system.md`, 7.15).

### `profileEmail-etapa1.png` e `-etapa2.png`. Trocar e-mail (`/profile/email`)

- Barra superior interna: voltar e o título **Trocar e-mail**.
- **Etapa 1:** o texto "E-mail atual: ana@exemplo.com", o campo **Novo e-mail**, a frase "Até você digitar o código, o e-mail atual continua valendo." e o botão principal **Enviar código**.
- **Etapa 2:** a frase com o novo e-mail, o campo de código, o botão principal **Confirmar** e o **Reenviar código**.

### `profilePassword.png`. Trocar senha (`/profile/password`)

- Barra superior interna: voltar e o título **Trocar senha**.
- Campos **Senha atual** e **Nova senha**, ambos com o olho.
- Botão principal **Salvar**.

## Fatia 3. Grupos

Detalhe de cada tela em `docs/ui/telas.md`, seção 6. Textos em `docs/copy.md`, seção 7. Para desenhar sem consultar os outros documentos, a mesma especificação está em `fatia-3/telas-fatia-3.md`, com os textos finais. Nos exemplos, use os grupos e as pessoas do seed (`setup.md`, seção 8): o **Vôlei de Quinta**, com Ana (admin), Bruno (apelido Brunão) e Carla (apelido Carlinha), e o código `VoleiQuinta1`. Quem pede para entrar é o Diego.

| Arquivo | Tela | Status |
|---------|------|--------|
| `groups.png` | Meus grupos, com dois grupos | Obrigatório |
| `groups-vazio.png` | Meus grupos sem nenhum grupo | Opcional |
| `groupsNew.png` | Criar grupo | Obrigatório |
| `groupsJoin-etapa1.png` e `groupsJoin-etapa2.png` | Entrar com código: o campo, e a prévia com Pedir para entrar | Obrigatório |
| `groupsJoin-pendente.png` | Entrar com código: a prévia com a solicitação pendente | Obrigatório |
| `groupsJoin-membro.png` | Entrar com código: a prévia de quem já é membro | Opcional |
| `group.png` e `group-membro.png` | Detalhe do grupo, visto pelo admin e por um membro | Obrigatório |
| `group-convite.png` e `group-convite-membro.png` | A sheet do convite, vista pelo admin e por um membro | Obrigatório |
| `group-convite-desativado.png` | A sheet do convite desativado, vista pelo admin | Opcional |
| `group-sair.png` | A confirmação de saída do grupo | Opcional: segue a confirmação destrutiva (`design-system.md`, 7.15), como `profilePix-remover.png` |
| `groupMembers.png` e `groupMembers-acoes.png` | Integrantes e a sheet de ações do admin | Obrigatório |
| `groupRequests.png` | Solicitações | Obrigatório |
| `groupEdit.png` | Editar grupo | Obrigatório |
| `person.png` | Perfil de outra pessoa | Obrigatório |

### `groups.png` e `groups-vazio.png`. Meus grupos (`/groups`)

- Barra superior de raiz com o título **Grupos**. A barra inferior aparece, com a aba Grupos ativa.
- Lista de grupos, em ordem alfabética. Cada linha: **avatar quadrado do grupo** de 44 (foto ou iniciais sobre pastel, cantos arredondados, `design-system.md`, 3.4), o **nome** e o subtítulo. No exemplo:
  - **Areia do Rio**, sem foto, "5 integrantes", em que a Ana é só membro;
  - **Vôlei de Quinta**, com foto, "3 integrantes · 2 solicitações", com o selo **Admin** à direita.
- No pé da tela, fixos: o botão principal **Criar grupo** e o botão de contorno **Entrar com código**.
- **`groups-vazio.png`:** o estado vazio, com o ícone de grupos, o título "Você ainda não está em nenhum grupo", a frase "Crie um grupo ou peça para entrar com o código de convite." e os mesmos dois botões.

### `groupsNew.png`. Criar grupo (`/groups/new`)

- Barra superior interna: voltar e o título **Criar grupo**.
- **Avatar quadrado de 96** (iniciais do nome digitado) com o botão de texto **Escolher foto**. A sheet que ele abre é a mesma de `profileEdit-foto.png` e não precisa de desenho novo.
- Campo **Nome do grupo**.
- Botão principal **Criar grupo**.

### `groupsJoin-etapa1.png`, `-etapa2.png`, `-pendente.png` e `-membro.png`. Entrar com código (`/groups/join`)

- Barra superior interna: voltar e o título **Entrar com código**.
- **Etapa 1:** a frase "Digite ou cole o código que você recebeu do grupo.", o campo **Código do convite** (no exemplo, `VoleiQuinta1`) e o botão principal **Continuar**. O código diferencia maiúsculas de minúsculas: mostre-o numa fonte em que dê para ver a diferença.
- **Etapa 2, a prévia:** o **avatar quadrado de 96** e o nome **Vôlei de Quinta**; a frase "Um admin do grupo precisa aprovar a sua entrada."; o botão principal **Pedir para entrar**; e o botão de texto **Usar outro código**.
- **`-pendente.png`:** a mesma prévia com um **aviso em linha** no lugar do botão principal (`design-system.md`, 7.14, quadrado de ícone com uma ampulheta em lilás): "Solicitação enviada. Aguardando a aprovação de um admin." Abaixo, a frase "O grupo aparece em Meus grupos quando a solicitação for aprovada.", o botão de contorno **Voltar aos grupos** e o **Usar outro código**.
- **`-membro.png`:** a prévia com a frase "Você já é membro deste grupo.", o botão principal **Abrir o grupo** e o **Usar outro código**.

### `group.png` e `group-membro.png`. Detalhe do grupo (`/groups/:groupId`)

- Barra superior interna com voltar. A barra inferior aparece, com a aba Grupos ativa.
- Cabeçalho: **avatar quadrado de 72** e o nome **Vôlei de Quinta**.
- Lista de linhas com seta:
  - **Integrantes**, com o subtítulo "3 pessoas";
  - **Solicitações**, com o subtítulo "2 solicitações pendentes" (só admin);
  - **Convite**, com o subtítulo "Código ativo";
  - **Editar grupo**, com o subtítulo "Nome e foto" (só admin).
- Botão destrutivo de contorno **Sair do grupo**.
- **`group-membro.png`:** a mesma tela vista pelo Bruno, sem as linhas Solicitações e Editar grupo.
- Deixe espaço abaixo das linhas: a fatia 4 acrescenta os jogos do grupo e o botão Criar jogo.

### `group-convite.png`, `-convite-membro.png` e `-convite-desativado.png`. Convite do grupo (sheet sobre o detalhe)

- Sheet (`design-system.md`, 7.15) com o título **Convite do grupo** e a frase "Quem tiver o código pode pedir para entrar. Um admin aprova cada solicitação."
- O código **`VoleiQuinta1`** em destaque. Não use Bebas Neue: ela só tem maiúsculas, e o código diferencia maiúsculas de minúsculas.
- Botão principal **Compartilhar** e botão de contorno **Copiar código**.
- Só para admin: os botões de texto **Gerar novo código** e **Desativar convite**, este em tom destrutivo.
- **`-convite-membro.png`:** a mesma sheet vista pelo Bruno, sem Gerar novo código e Desativar convite.
- **`-convite-desativado.png`:** a frase "O convite está desativado." e o botão principal **Gerar código**. O membro veria a frase "Peça a um admin para gerar um novo código.", sem botão.
- As confirmações de Gerar novo código e Desativar convite seguem `profilePix-remover.png` e não precisam de desenho.

### `group-sair.png`. Sair do grupo, opcional

A confirmação destrutiva, com o título **Sair do grupo Vôlei de Quinta?**, a frase "Para voltar, você vai precisar do código e da aprovação de um admin.", o botão destrutivo sólido **Sair do grupo** e o botão de contorno **Voltar**.

### `groupMembers.png` e `groupMembers-acoes.png`. Integrantes (`/groups/:groupId/members`)

- Barra superior interna: voltar e o título **Integrantes**.
- Lista, com os admins primeiro e depois os membros, em ordem alfabética. Cada linha: **avatar de 44**, o nome e o subtítulo da data de entrada. No exemplo, vista pela Ana:
  - **Ana (você)**, avatar amarelo "Você", "Entrou em 02/11/2026", selo **Admin**;
  - **Brunão**, "Entrou em 05/11/2026";
  - **Carlinha**, "Entrou em 09/11/2026".
- **`groupMembers-acoes.png`:** a sheet que abre quando a Ana toca no Brunão, com o título **Brunão** e as opções **Ver perfil**, **Tornar admin** e **Remover do grupo**, esta em tom destrutivo. A sheet de quando a Ana toca em si mesma, só com **Deixar de ser admin**, segue o mesmo desenho.

### `groupRequests.png`. Solicitações (`/groups/:groupId/requests`)

- Barra superior interna: voltar e o título **Solicitações**.
- Lista de solicitações pendentes. Cada linha: **avatar de 44**, o nome e o subtítulo "Pediu em qui, 12/11", e duas ações: **Recusar** (contorno) e **Aprovar** (preenchida). No exemplo, Diego e uma segunda pessoa.
- O estado vazio ("Nenhuma solicitação pendente") segue o `design-system.md` (7.16) e não precisa de desenho.

### `groupEdit.png`. Editar grupo (`/groups/:groupId/edit`)

- Barra superior interna: voltar e o título **Editar grupo**.
- **Avatar quadrado de 96** com o botão de texto **Trocar foto** (a sheet é a de `profileEdit-foto.png`).
- Campo **Nome do grupo**.
- Botão principal **Salvar**.
- Botão destrutivo de contorno **Excluir grupo**. A confirmação segue `profilePix-remover.png`, com o título "Excluir o grupo Vôlei de Quinta?" e uma frase mais longa, e não precisa de desenho.

### `person.png`. Perfil de outra pessoa (`/people/:userId`)

- Barra superior interna com voltar. A barra inferior aparece, com a aba de origem ativa.
- **Avatar de 96**, o nome exibido **Brunão** e, embaixo, em tom secundário, o nome **Bruno** (no seed, o nome do Bruno é só "Bruno").
- Deixe espaço abaixo: a fatia 4 acrescenta o telefone, quando a pessoa o deixa visível.
