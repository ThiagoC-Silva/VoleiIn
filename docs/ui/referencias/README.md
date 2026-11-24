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

## Fatia 4. Jogo e lista de presença

Detalhe de cada tela em `docs/ui/telas.md`, seção 7. Textos em `docs/copy.md`, seção 8. Para desenhar sem consultar os outros documentos, a mesma especificação está em `fatia-4/telas-fatia-4.md`, com os textos finais. Nos exemplos, use o **Vôlei de Quinta** e as pessoas do seed (`setup.md`, seção 8): Ana (admin do grupo, admin do jogo e recebedora), Bruno (apelido Brunão) e Carla (apelido Carlinha). O jogo de exemplo é na **Quadra do Sesc**, no **sáb, 21/11**, das **20:00 às 22:00**, com prazo de cancelamento na **sex, 20/11, às 18:00**, valor total de **R$ 120,00** e **12 vagas** (estimativa de R$ 10,00 por pessoa).

| Arquivo | Tela | Status |
|---------|------|--------|
| `games.png` | Meus jogos, chip Próximos, com três jogos | Obrigatório |
| `games-anteriores.png` | Meus jogos, chip Anteriores, com um jogo cancelado | Opcional: mesmo card de `games.png` |
| `games-vazio.png` | Meus jogos sem nenhum jogo | Opcional: segue o estado vazio do `design-system.md` (7.16), como `groups-vazio.png` |
| `gamesNew.png` | Criar jogo, preenchido | Obrigatório |
| `gamesNew-semPix.png` | Criar jogo sem chave Pix | Opcional: aviso em linha (`design-system.md`, 7.14) |
| `game.png` | Detalhe do jogo Aberto, visto pelo Bruno, que está na lista | Obrigatório |
| `game-admin.png` | Detalhe do mesmo jogo, visto pela Ana, com o menu do admin aberto | Obrigatório |
| `game-confirmado.png` | Detalhe de um jogo Confirmado com lista de espera, visto por quem está fora | Obrigatório |
| `game-espera.png` | Detalhe do jogo Confirmado, visto por quem está na espera | Opcional: aviso em linha no pé |
| `game-andamento.png` | Detalhe de um jogo em andamento | Opcional: o selo "Em andamento" no topo |
| `game-cancelado.png` | Detalhe de um jogo cancelado | Opcional: topo em `surfaceHigh` (`design-system.md`, 7.8) |
| `game-sair.png` | Confirmação de saída depois do prazo | Opcional: segue a confirmação destrutiva, como `group-sair.png` |
| `game-participante.png` | Sheet do admin ao tocar num participante | Opcional: segue `groupMembers-acoes.png` |
| `gameEdit.png` | Editar jogo | Opcional: os campos de `gamesNew.png`, com o grupo só como texto e a dica no contador |
| `gameAdmins.png` | Admins do jogo | Obrigatório |
| `gameAdmins-adicionar.png` | Sheet de adicionar admin | Opcional: lista de pessoas numa sheet |
| `group-jogos.png` | Detalhe do grupo com os próximos jogos e o botão Criar jogo | Obrigatório |
| `group-sairBloqueado.png` | Sheet de bloqueio da saída do grupo | Obrigatório |
| `person-telefone.png` | Perfil de outra pessoa com o telefone visível | Obrigatório |

### `games.png`, `-anteriores.png` e `-vazio.png`. Meus jogos (`/games`)

- Barra superior de raiz com o título **Jogos**. A barra inferior aparece, com a aba Jogos ativa.
- Dois chips de filtro: **Próximos** (ativo) e **Anteriores**.
- Cards de jogo (`design-system.md`, 7.12): à esquerda, o bloco da data (dia da semana, dia e hora); ao lado, o nome do grupo ou "Avulso", o local, as vagas ("3/12"), a pílula do status e, quando houver, o selo da situação da pessoa; embaixo, a barra de ocupação. No exemplo, vistos pelo Brunão:
  - **Vôlei de Quinta**, Quadra do Sesc, sáb 21/11 às 20:00, "3/12", pílula **Aberto**, selo **Na lista**;
  - **Vôlei de Quinta**, Ginásio Verdão, dom 22/11 às 20:00, "2/2", pílula **Confirmado**, selo **1º na espera**;
  - **Vôlei de Quinta**, Arena Delta, ter 24/11 às 19:00, "2/8", pílula **Aberto**, sem selo (o jogo da Carla, de que ele não participa).
- No pé da tela, fixo, o botão principal **Criar jogo**.
- **`-anteriores.png`:** o chip Anteriores ativo e um card de jogo cancelado, com o selo vermelho **Cancelado**.
- **`-vazio.png`:** o estado vazio com o ícone de vôlei, o título "Nenhum jogo marcado", a frase "Crie um jogo ou espere alguém dos seus grupos marcar um." e o botão **Criar jogo**.

### `gamesNew.png` e `-semPix.png`. Criar jogo (`/games/new`)

- Barra superior interna: voltar e o título **Criar jogo**. Cobre a barra inferior. A tela rola.
- Campos, de cima para baixo: **Grupo** (campo de seleção, com "Vôlei de Quinta"); **Nome do local** ("Quadra do Sesc"); **Link do Google Maps (opcional)**; **Data do jogo** ("21/11/2026"); **Início** e **Fim** lado a lado ("20:00" e "22:00"); **Prazo de cancelamento**, com data e hora lado a lado ("20/11/2026" e "18:00") e a dica "Até esse horário, quem sair da lista não paga multa."; **Valor total do espaço** (prefixo `R$`, "120,00" em Bebas Neue); **Limite de vagas** (contador com − e +, "12" no centro).
- Aviso em linha azul (`split`) com uma calculadora: "Cerca de R$ 10,00 por pessoa" e a frase "É só uma estimativa. A divisão final é feita na conclusão do jogo."
- Aviso em linha verde-água (`receive`) com o ícone do Pix: "Você vai ser o recebedor deste jogo. Quem entrar na lista vê a sua chave Pix."
- Botão principal **Criar jogo**, no fim.
- **`-semPix.png`:** no topo, aviso em linha coral (`owe`) com o ícone do Pix: "Quem cria o jogo é o recebedor: quem entrar na lista paga a você. Cadastre uma chave Pix para continuar." e o botão de contorno **Cadastrar chave Pix**. O botão **Criar jogo** aparece desabilitado.
- A sheet do campo Grupo (os grupos e **Avulso**) segue a sheet de opções de `groupMembers-acoes.png` e não precisa de desenho. Com Avulso, o campo mostra a dica "Num jogo avulso, só entra quem receber o convite do jogo."

### `game.png`. Detalhe do jogo, visto pelo Bruno (`/games/:gameId`)

- Barra superior interna com voltar. A barra inferior aparece, com a aba Jogos ativa.
- **Topo colorido amarelo** (`game`, `design-system.md`, 7.8): pílula "Vôlei de Quinta", "sáb, 21/11", "20:00 – 22:00" grande, "Quadra do Sesc", pílula **Aberto**, botão circular do mapa e o anel de vagas com 12 gomos, 3 cheios.
- **Trio de números:** Vagas "3/12"; Por pessoa "R$ 10,00" (azul, `split`); Prazo "sex, 20/11, 18:00".
- **Recebedor:** linha com o avatar da Ana, "Ana" e o selo **Recebedor**; embaixo, a chave "CPF · 123.456.789-09" e o botão de texto **Copiar chave**.
- **Lista · 3 de 12:** 1 Ana (selos **Recebedor** e **Admin**), 2 Brunão (você, avatar amarelo), 3 Carlinha.
- No pé, fixo, o botão destrutivo de contorno **Sair da lista**.

### `game-admin.png`. Detalhe do jogo, visto pela Ana

- O mesmo jogo, com o botão de menu (três pontos) na barra superior, **aberto**: **Editar jogo**, **Admins do jogo** e **Cancelar jogo** (em tom destrutivo).
- No pé, no lugar do botão de sair, o aviso em linha com um cadeado: "Você é o recebedor deste jogo e não pode sair da lista. Se não puder jogar, o jogo precisa ser cancelado por um admin."
- A sheet que abre quando a Ana toca no Brunão (`game-participante.png`, opcional) tem o título **Brunão** e as opções **Ver perfil** e **Remover da lista**, esta em tom destrutivo.

### `game-confirmado.png` e `-espera.png`. Jogo Confirmado com espera

- **Topo colorido lilás** (`wait`): pílula "Vôlei de Quinta", "dom, 22/11", "20:00 – 22:00", "Ginásio Verdão", pílula **Confirmado**, anel com 2 gomos cheios.
- Trio: Vagas "2/2"; Por pessoa "R$ 30,00"; Prazo "dom, 22/11, 18:00".
- Recebedor: a Ana, **sem a chave**, com a frase "A chave Pix do recebedor aparece para quem está na lista."
- **Lista · 2 de 2:** 1 Ana, 2 Carlinha.
- **Lista de espera · 1:** Brunão, com o selo lilás **1º na espera**.
- Visto por quem está fora (no exemplo, um terceiro membro do grupo): no pé, a frase "A lista está cheia. Na espera, você é avisado quando abrir uma vaga." e o botão principal **Entrar na lista de espera**.
- **`-espera.png`:** visto pelo Brunão. No pé, o aviso em linha lilás com uma ampulheta: "Você é o 1º na espera. Quando abrir uma vaga, ela fica com quem entrar primeiro." e o botão de contorno **Sair da lista de espera**.

### `game-andamento.png`, `-cancelado.png` e `-sair.png`, opcionais

- **`-andamento.png`:** o topo ganha o selo **Em andamento** ao lado da pílula do status. Não há lista de espera. Depois do fim, o selo vira **Aguardando conclusão**, e o pé mostra o aviso "A lista está travada até a conclusão do jogo."
- **`-cancelado.png`:** o topo em azul-acinzentado (`surfaceHigh`), com o selo vermelho **Cancelado**, sem botões no pé.
- **`-sair.png`:** a confirmação destrutiva com o título **Sair da lista?**, a frase "O prazo de cancelamento já passou. A saída pode gerar uma multa igual à parte por vaga, decidida na conclusão do jogo.", o botão destrutivo sólido **Sair da lista** e o botão de contorno **Voltar**.

### `gameEdit.png`. Editar jogo, opcional

Os campos de `gamesNew.png` sem o campo Grupo: no lugar dele, o nome "Vôlei de Quinta" só como texto. No contador, a dica "3 pessoas na lista", com o − desabilitado no 3. O aviso da estimativa continua, e o do recebedor sai. Botão principal **Salvar**.

### `gameAdmins.png` e `-adicionar.png`. Admins do jogo (`/games/:gameId/admins`)

- Barra superior interna: voltar e o título **Admins do jogo**.
- Lista dos admins, em ordem alfabética, com avatar, nome e subtítulo. No exemplo: **Ana (você)**, "Na lista"; **Brunão**, "Fora da lista".
- No pé, o botão principal **Adicionar admin**.
- **`-adicionar.png`:** sheet com o título **Quem vai ser admin?** e a lista de quem está na lista e ainda não é admin (no exemplo, a Carlinha), cada uma com avatar e nome.

### `group-jogos.png`. Detalhe do grupo com os jogos

- O detalhe do grupo de `group.png`, visto pela Ana, com uma seção nova entre as linhas e o **Sair do grupo**: o título **Próximos jogos** e dois cards de jogo (os dois primeiros de `games.png`).
- O botão principal **Criar jogo**, abaixo dos cards.
- Sem jogos, a seção mostra a frase "Nenhum jogo marcado neste grupo." (não precisa de desenho).

### `group-sairBloqueado.png`. Sheet de bloqueio da saída do grupo

- Sheet com o título **Você ainda não pode sair do grupo**.
- A frase "Você é o recebedor destes jogos, que ainda não foram concluídos. Para sair do grupo, os jogos precisam ser cancelados ou concluídos."
- Um card de jogo (no exemplo, o jogo da Carla: **Vôlei de Quinta**, Arena Delta, ter 24/11 às 19:00, vista pela Carla).
- Botão de contorno **Voltar**.
- A variação de quem é o único admin troca só a frase: "Você é o único admin destes jogos. Indique outro admin em Admins do jogo antes de sair."

### `person-telefone.png`. Perfil de outra pessoa com telefone (`/people/:userId`)

- O perfil de `person.png`, com a Ana: avatar de 96, "Ana".
- Abaixo do nome, a linha **Telefone** com "(86) 99999-8888" e dois botões de contorno lado a lado: **Ligar** e **WhatsApp**.

## Fatia 5. Conclusão, multas e rateio

Detalhe de cada tela em `docs/ui/telas.md`, seção 8. Textos em `docs/copy.md`, seção 9. Para desenhar sem consultar os outros documentos, a mesma especificação está em `fatia-5/telas-fatia-5.md`, com os textos finais e o exemplo completo do rateio (R$ 250,00, 12 vagas, R$ 20,84 por vaga, R$ 229,24 a receber).

| Arquivo | Tela | Status |
|---------|------|--------|
| `game-aguardando.png` | Detalhe depois do fim, visto pela admin, com **Concluir jogo** no pé | Obrigatório |
| `gameComplete.png` | Concluir jogo, com uma falta marcada e o resumo do rateio | Obrigatório |
| `gameComplete-vagas.png` | Concluir jogo com o aviso de vagas sem ninguém | Opcional: aviso em linha (`design-system.md`, 7.14) |
| `gameComplete-confirmar.png` | Confirmação da conclusão | Opcional: segue as confirmações da fatia 4, em tom normal |
| `gameSplit-recebedor.png` | Rateio visto pela recebedora | Obrigatório |
| `gameSplit-isentar.png` | Sheet de isentar a multa | Opcional: segue `game-participante.png` |
| `gameSplit.png` | Rateio visto por um participante | Obrigatório |
| `game-concluido.png` | Detalhe do jogo concluído, com Sua participação e o card do rateio | Obrigatório |
| `game-trocarRecebedor.png` | Sheet de trocar recebedor, depois da conclusão | Obrigatório |
| `charges.png` | Cobranças, com valores a pagar e a receber | Obrigatório |
| `charges-vazio.png` | Cobranças sem nenhum valor | Opcional: estado vazio (`design-system.md`, 7.16) |

## Fatia 6. Pagamentos, comprovantes e exclusão de conta

Detalhe de cada tela em `docs/ui/telas.md`, seção 9. Textos em `docs/copy.md`, seção 10. Para desenhar sem consultar os outros documentos, a mesma especificação está em `fatia-6/telas-fatia-6.md`, com os textos finais e os exemplos. A fatia roda em três etapas, e a sessão 3 de cada uma só precisa dos PNGs dela.

| Arquivo | Tela | Etapa | Status |
|---------|------|-------|--------|
| `charge.png` | Valor a pagar Pendente, com a chave Pix | A e B | Obrigatório |
| `charge-pago.png` | Valor a pagar Pago | A | Opcional: o mesmo desenho, em `receive` |
| `gameSplit-marcarPago.png` | Sheet da pessoa no Rateio | A | Opcional: segue `gameSplit-isentar.png` |
| `charge-analise.png` | Valor a pagar Em análise | B | Opcional: o mesmo desenho, em `split`, com aviso em linha |
| `charge-enviar1.png`, `charge-enviar2.png` e `charge-enviar4.png` | Enviar comprovante: escolher, conferir e resultado | B | Obrigatório |
| `charge-enviar3.png` | Enviar comprovante: lendo | B | Opcional |
| `receipt.png` e `receipt-pagador.png` | Comprovante, visto pelo recebedor e pelo pagador | B | Obrigatório |
| `receipt-recusar.png` | Sheet de recusar | B | Opcional |
| `charges-conferir.png` | Cobranças com Para conferir | B | Obrigatório |
| `profileDelete.png` e `profileDelete-bloqueada.png` | Excluir conta, e com os bloqueios | C | Obrigatório |
