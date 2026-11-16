# VoleiIn: telas de jogo e lista de presença

## Sobre o app

O VoleiIn é um app Android, em português do Brasil, para grupos de vôlei. Ele organiza jogos e listas de presença, calcula a divisão do valor da quadra e acompanha os pagamentos por Pix entre os participantes. O app não processa pagamentos.

Este documento descreve as telas de **jogos**: ver os próprios jogos, criar um jogo, ver o detalhe com a lista de presença e a lista de espera, entrar e sair, editar, cancelar, gerenciar os admins do jogo, os jogos dentro do grupo, o aviso de quando alguém não pode sair do grupo e o telefone no perfil de outra pessoa.

## Como os jogos funcionam

- Qualquer membro de um grupo cria um jogo no grupo. Também dá para criar um jogo **avulso**, fora de grupo: nele, só entra quem receber o convite do jogo.
- O jogo tem: local (nome e, se quiser, o link do Google Maps), data, horário de início e de fim, **prazo de cancelamento** (data e hora), **valor total** do espaço e **limite de vagas**.
- Quem cria o jogo vira o **admin** do jogo, o **recebedor** (quem pagou a quadra e recebe o Pix de todos) e o **primeiro da lista**. Para criar, a pessoa precisa ter uma chave Pix cadastrada.
- Os participantes da lista veem a **chave Pix do recebedor**. Quem não está na lista não vê.
- A **estimativa por pessoa** é o valor total dividido pelo limite de vagas. É só informativa: a divisão final é feita quando o jogo é concluído (numa próxima etapa do app).
- O jogo tem um **status**:
  - **Aberto**: ainda tem vaga;
  - **Confirmado**: a lista encheu;
  - **Cancelado**: o jogo não acontece;
  - **Concluído**: o jogo aconteceu e o valor foi dividido (numa próxima etapa).
- Com a lista cheia, a pessoa entra na **lista de espera**. A espera não dá prioridade: quando abre uma vaga, quem está na espera é avisado, e a vaga fica com quem entrar primeiro.
- **Sair da lista:**
  - até o prazo de cancelamento, sem multa;
  - depois do prazo e antes do início, pode gerar uma multa igual à parte de cada vaga;
  - depois do início, a saída vira falta, com multa, e a vaga continua contando;
  - depois do horário de fim, a lista trava até a conclusão.
- O **recebedor não sai da lista**. Se não puder jogar, um admin cancela o jogo.
- O jogo pode ter vários admins. Só quem está na lista vira admin, mas quem já é admin continua admin se sair da lista. O jogo sempre tem pelo menos um admin.
- Os admins do jogo editam (só antes do início), cancelam, removem pessoas da lista (só antes do início) e gerenciam os outros admins.
- Quem quer sair de um grupo não consegue enquanto for o recebedor ou o único admin de um jogo do grupo que ainda não foi concluído.

## Pessoas, grupo e jogos dos exemplos

- **Vôlei de Quinta**, o grupo. Integrantes:
  - **Ana**, admin do grupo. Cria os jogos, então é a **recebedora** e **admin** deles. Chave Pix CPF `123.456.789-09`. Telefone visível: (86) 99999-8888;
  - **Bruno**, com o apelido **Brunão**;
  - **Carla**, com o apelido **Carlinha**.
- **Jogo 1:** Vôlei de Quinta, **Quadra do Sesc**, **sáb, 21/11**, das **20:00 às 22:00**, prazo de cancelamento **sex, 20/11, às 18:00**, **R$ 120,00**, **12 vagas** (cerca de **R$ 10,00** por pessoa). Na lista: Ana, Brunão e Carlinha. Status **Aberto**.
- **Jogo 2:** Vôlei de Quinta, **Ginásio Verdão**, **dom, 22/11**, das **20:00 às 22:00**, prazo **dom, 22/11, às 18:00**, **R$ 60,00**, **2 vagas** (R$ 30,00 por pessoa). Na lista: Ana e Carlinha. Na espera: Brunão. Status **Confirmado**.
- **Jogo 3:** **Avulso**, **Praia do Coqueiro**, **qui, 26/11**, das **18:00 às 20:00**, **R$ 40,00**, **4 vagas**. Na lista: Ana. Status **Aberto**.
- **Jogo da Carla:** Vôlei de Quinta, **Arena Delta**, **ter, 24/11**, das **19:00 às 21:00**, **R$ 80,00**, **8 vagas**. Na lista: Carlinha e Ana. A Carla é a recebedora.

Nas listas, o app mostra o apelido e, se a pessoa não tiver, o nome.

## Regras gerais

As regras das telas de grupos continuam valendo: só modo escuro, largura de 360 dp, tom informal com "você", botões com verbo no infinitivo, área de toque de 48 × 48 dp, fonte do sistema em 150% sem nada cortado, um botão principal por tela, rótulo dos campos acima do campo, os tipos de botão, os avatares, o selo em pílula, a linha de lista, a folha (sheet), a confirmação destrutiva e os estados comuns (enviando, erro de ação, erro de campo, carregando, falha, não encontrado, puxar para atualizar).

**Fontes:** Montserrat nos títulos e nomes; **Bebas Neue só nos números** (horários, valores, vagas, posição na espera); Roboto no resto.

**Cores dos blocos grandes**, sempre com texto azul-marinho escuro (`#192853`), nunca branco:

| Cor | Hex | Significa |
|-----|-----|-----------|
| Amarelo | `#FFE14F` | Jogo Aberto, ação principal |
| Lilás | `#B8A6FF` | Lista de espera, jogo Confirmado (lista cheia) |
| Azul-claro | `#8EC5FF` | Estimativa por pessoa, avisos informativos |
| Verde-água | `#7CDCC8` | Você recebe (o recebedor) |
| Coral | `#FF8F6B` | Você deve, falta de algo para pagar ou receber |

No máximo um bloco grande por tela e dois pequenos.

**Componentes novos nesta etapa:**

- **Card de jogo:** à esquerda, um bloco de data estreito, mais claro que o card, com o dia da semana pequeno, o dia grande (Bebas Neue) e a hora em amarelo. Ao lado: o nome do grupo (pequeno) ou "Avulso", o local (título), as vagas ("3/12", em Bebas Neue), a pílula do status e, se houver, o selo da situação da pessoa. Embaixo, uma barra fina de ocupação: amarela com vagas, lilás com a lista cheia.
- **Pílula do status:** Aberto em amarelo, Confirmado em lilás, Concluído em branco-gelo, todos com texto escuro; **Cancelado** é um selo vermelho discreto.
- **Selos da pessoa no jogo:** **Na lista** (verde), **Saiu após o início** (vermelho), **1º na espera** (lilás). E os de papel, neutros: **Recebedor** e **Admin**.
- **Selos de tempo:** **Em andamento** e **Aguardando conclusão**, discretos (fundo azul-acinzentado e ponto azul-claro), ao lado da pílula do status.
- **Topo colorido do jogo:** bloco no alto do detalhe, com os cantos de baixo bem arredondados, amarelo com o jogo Aberto, lilás com o Confirmado e azul-acinzentado (`#2A3A68`, texto claro) com o Cancelado. Tem a pílula do grupo (ou "Avulso"), a data, o horário grande em Bebas Neue ("20:00 – 22:00"), o local, a pílula do status, os botões circulares escuros (voltar, mapa) e um **anel segmentado** com um gomo por vaga, cheio nas ocupadas.
- **Trio de números:** três cards pequenos lado a lado, logo abaixo do topo, cada um com um rótulo pequeno e um número em Bebas Neue: Vagas, Por pessoa (este em azul-claro) e Prazo.
- **Contador de vagas:** campo com um botão circular − (escuro) à esquerda, o número no centro (Bebas Neue, dá para digitar) e um botão circular + (amarelo) à direita.
- **Chips de filtro:** pílulas; a ativa tem fundo branco-gelo e texto escuro, a inativa só contorno.
- **Aviso em linha:** card com um quadrado de ícone colorido à esquerda e o texto ao lado. Usado para explicar algo ou um bloqueio.
- **Campo de dinheiro:** prefixo `R$` e o valor em Bebas Neue.
- **Campos de data e hora:** abrem o seletor do Android e mostram `21/11/2026` e `20:00`.

**Barra inferior:** Jogos, Grupos, Cobranças e Perfil. Aparece nas telas da aba Jogos marcadas abaixo, com **Jogos** ativo. Criar e editar jogo cobrem a barra.

## Fluxo entre as telas

1. A aba **Jogos** abre em **Meus jogos**.
2. Em Meus jogos, a pessoa toca num card, que abre o **Detalhe do jogo**, ou em **Criar jogo**.
3. No **Detalhe do grupo**, a seção **Próximos jogos** também abre o Detalhe do jogo, e o botão **Criar jogo** abre a criação com o grupo já escolhido.
4. No **Detalhe do jogo**, a pessoa entra ou sai da lista e da espera. O admin abre, pelo menu de três pontos, **Editar jogo**, **Admins do jogo** e **Cancelar jogo**, e remove pessoas tocando na linha delas.
5. Tocar numa pessoa da lista abre o **Perfil de outra pessoa**, que mostra o telefone quando ela deixa visível.

---

## 1. Meus jogos

**Objetivo:** ver os jogos dos grupos da pessoa e os jogos em que ela está ou esteve. É a tela da aba **Jogos**: a barra inferior aparece, com Jogos ativo.

**Conteúdo, de cima para baixo:**

1. Barra superior de tela principal, com o título **Jogos** grande.
2. Dois chips: **Próximos** (ativo ao abrir) e **Anteriores**.
3. Os cards de jogo. Em **Próximos**, os jogos Abertos e Confirmados, do mais cedo para o mais tarde. Em **Anteriores**, os concluídos e os cancelados, do mais recente para o mais antigo. Um jogo cancelado vai direto para Anteriores.

   No exemplo, o Brunão vê em Próximos:
   - Vôlei de Quinta, Quadra do Sesc, sáb 21/11 às 20:00, "3/12", **Aberto**, selo **Na lista**;
   - Vôlei de Quinta, Ginásio Verdão, dom 22/11 às 20:00, "2/2", **Confirmado**, selo **1º na espera**;
   - Vôlei de Quinta, Arena Delta, ter 24/11 às 19:00, "2/8", **Aberto**, sem selo: é o jogo da Carla, de que ele não participa.

   Num jogo avulso, o card mostra "Avulso" no lugar do nome do grupo.
4. No pé da tela, fixo, o botão principal **Criar jogo**.

**Sem nenhum jogo em Próximos:** um ícone de vôlei, o título "Nenhum jogo marcado" e a frase "Crie um jogo ou espere alguém dos seus grupos marcar um." O botão do pé continua.

**Sem nenhum jogo em Anteriores:** um ícone de histórico, o título "Nenhum jogo anterior" e a frase "Os jogos concluídos e cancelados aparecem aqui."

---

## 2. Criar jogo

**Objetivo:** criar um jogo. Quem cria vira admin, recebedor e primeiro da lista.

**Conteúdo, de cima para baixo** (a tela rola):

1. Barra superior interna com o título **Criar jogo**.
2. **Grupo:** campo de seleção. Ao tocar, abre uma folha com o título "Onde é o jogo?", os grupos da pessoa e a opção **Avulso**. Com Avulso, o campo mostra a dica "Num jogo avulso, só entra quem receber o convite do jogo."
3. **Nome do local**.
4. **Link do Google Maps (opcional)**, com a dica "Cole o link do local no Google Maps."
5. **Data do jogo**.
6. **Início** e **Fim**, lado a lado. Se o fim for mais cedo que o início, o jogo termina no dia seguinte, e o campo do fim mostra a dica "Termina dom, 22/11."
7. **Prazo de cancelamento:** data e hora, lado a lado, com a dica "Até esse horário, quem sair da lista não paga multa."
8. **Valor total do espaço**, com `R$`.
9. **Limite de vagas**, com o contador.
10. Aviso em linha azul-claro, com o ícone de calculadora: "Cerca de R$ 10,00 por pessoa" e, menor, "É só uma estimativa. A divisão final é feita na conclusão do jogo." Só aparece com o valor e o limite preenchidos.
11. Aviso em linha verde-água, com o ícone do Pix: "Você vai ser o recebedor deste jogo. Quem entrar na lista vê a sua chave Pix."
12. Botão principal **Criar jogo**.

Todos os campos começam vazios. No desenho, mostre o jogo 1 preenchido.

**Sem chave Pix:** no topo, antes do campo Grupo, um aviso em linha coral, com o ícone do Pix: "Quem cria o jogo é o recebedor: quem entrar na lista paga a você. Cadastre uma chave Pix para continuar." e o botão de contorno **Cadastrar chave Pix**. O aviso verde-água do recebedor não aparece, e o botão **Criar jogo** fica desabilitado.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Campo obrigatório vazio | Erro no campo: "Informe o local.", "Escolha a data.", "Escolha o horário.", "Informe o valor total.", "Informe o limite de vagas.", "Escolha o grupo do jogo." |
| Local com mais de 120 caracteres | "O local pode ter até 120 caracteres." |
| Link que não começa com https:// | "O link precisa começar com https://." |
| Fim igual ao início | "O fim precisa ser depois do início." |
| Início no passado | "O início precisa estar no futuro." |
| Prazo depois do início | "O prazo não pode passar do início do jogo." |
| Sucesso | Abre o Detalhe do jogo novo, com o *snackbar* "Jogo criado." O voltar não retorna à criação |

---

## 3. Detalhe do jogo

**Objetivo:** ver o jogo, a lista e a espera, entrar e sair. A barra inferior aparece, com Jogos ativo.

**Conteúdo, de cima para baixo**, no exemplo do jogo 1 visto pelo **Brunão**:

1. **Topo colorido amarelo**, com o botão circular de voltar, a pílula "Vôlei de Quinta", "sáb, 21/11", "20:00 – 22:00" grande, "Quadra do Sesc", a pílula **Aberto**, o botão circular de mapa (abre o Google Maps) e o anel com 12 gomos, 3 cheios.
2. **Trio:** Vagas "3/12"; Por pessoa "R$ 10,00" (azul-claro); Prazo "sex, 20/11, 18:00".
3. **Recebedor:** linha com o avatar da Ana, o nome "Ana" e o selo **Recebedor**. Embaixo, a chave "CPF · 123.456.789-09" e o botão de texto **Copiar chave**. Para quem não está na lista, no lugar da chave, a frase "A chave Pix do recebedor aparece para quem está na lista."
4. **Lista · 3 de 12**, numerada pela ordem de entrada:
   1. Ana, com os selos **Recebedor** e **Admin**;
   2. Brunão (você), com o avatar amarelo;
   3. Carlinha.

   Quem saiu depois do início continua na lista, com o selo vermelho **Saiu após o início**.
5. **Lista de espera · N**, só antes do início e quando há alguém nela: as pessoas pela ordem de entrada, cada uma com o selo lilás **1º na espera**, **2º na espera**...
6. **Pé da tela, fixo**, com a ação da pessoa:

| Situação | Pé da tela |
|----------|------------|
| Fora da lista, jogo Aberto | Botão principal **Entrar na lista** |
| Fora da lista, jogo Confirmado | A frase "A lista está cheia. Na espera, você é avisado quando abrir uma vaga." e o botão principal **Entrar na lista de espera** |
| Não é do grupo, ou jogo avulso de outra pessoa | A frase "Para entrar neste jogo, você precisa do convite dele.", sem botão |
| Na espera, jogo Aberto | Botão principal **Entrar na lista** e botão de texto **Sair da lista de espera** |
| Na espera, jogo Confirmado | Aviso em linha lilás com ampulheta: "Você é o 1º na espera. Quando abrir uma vaga, ela fica com quem entrar primeiro." e o botão de contorno **Sair da lista de espera** |
| Na lista (no exemplo, o Brunão) | Botão destrutivo de contorno **Sair da lista** |
| Na lista e recebedor (a Ana) | Aviso em linha com cadeado: "Você é o recebedor deste jogo e não pode sair da lista. Se não puder jogar, o jogo precisa ser cancelado por um admin." Sem botão |
| Depois do horário de fim | Aviso em linha com cadeado: "A lista está travada até a conclusão do jogo." |
| Jogo cancelado | Nada |

**Para os admins do jogo (a Ana):** um botão de menu de três pontos na barra de cima. O menu tem **Editar jogo** (só antes do início), **Admins do jogo** e **Cancelar jogo**, este em tom destrutivo. Tocar em outra pessoa da lista, antes do início, abre uma folha com o nome dela como título e as opções **Ver perfil** e **Remover da lista**, esta em tom destrutivo. Quem não é admin, ao tocar numa pessoa, abre o perfil dela.

**Jogo Confirmado (jogo 2):** o topo é **lilás**, com a pílula **Confirmado** e o anel com 2 gomos cheios. Trio: "2/2", "R$ 30,00", "dom, 22/11, 18:00". Lista · 2 de 2: Ana e Carlinha. Lista de espera · 1: Brunão, com **1º na espera**.

**Em andamento:** o topo ganha o selo **Em andamento**. Depois do fim, **Aguardando conclusão**. Não há lista de espera.

**Cancelado:** o topo fica azul-acinzentado, com o selo vermelho **Cancelado**, e o pé fica vazio.

**Confirmações:**

| Ação | Título | Frase | Botão destrutivo sólido |
|------|--------|-------|-------------------------|
| Sair, antes do prazo | Sair da lista? | "Saindo até sex, 20/11, 18:00, você não paga multa, e a vaga fica livre para outra pessoa." | Sair da lista |
| Sair, depois do prazo | Sair da lista? | "O prazo de cancelamento já passou. A saída pode gerar uma multa igual à parte por vaga, decidida na conclusão do jogo." | Sair da lista |
| Sair, em andamento | Sair da lista? | "O jogo já começou. A saída fica registrada como falta, com multa igual à parte por vaga, e a vaga continua contando." | Sair da lista |
| Remover da lista | Remover Brunão da lista? | "Brunão sai da lista sem multa, e a vaga fica livre para outra pessoa." | Remover |
| Cancelar o jogo | Cancelar o jogo? | "O jogo não acontece e ninguém paga nada. Quem está na lista e na espera é avisado. Não dá para desfazer." | Cancelar jogo |

Todas com o botão de contorno **Voltar**.

**Snackbars:** "Você entrou na lista.", "Você entrou na lista de espera.", "Você saiu da lista de espera.", "Você saiu da lista, sem multa.", "Você saiu da lista depois do prazo. A multa é decidida na conclusão do jogo.", "Você saiu do jogo. A falta ficou registrada.", "Removemos Brunão da lista.", "Jogo cancelado.", "Chave Pix copiada."

**Ao vivo:** a lista, a espera e o status mudam sozinhos quando alguém entra ou sai, sem puxar a tela.

---

## 4. Editar jogo

**Objetivo:** mudar os dados do jogo antes do início. Só para admins do jogo. Cobre a barra inferior.

**Conteúdo:** barra superior interna com o título **Editar jogo**; o nome do grupo só como texto ("Vôlei de Quinta"), sem poder mudar; os campos de Criar jogo (itens 3 a 9), já preenchidos; o aviso da estimativa; e o botão principal **Salvar**. No contador, a dica "3 pessoas na lista", e o botão − fica desabilitado no 3, porque o limite não pode ficar abaixo de quem já está na lista.

**Comportamento:** sucesso volta ao detalhe com o *snackbar* "Jogo salvo." Depois do início, no lugar do formulário, o aviso "O jogo já começou. Depois do início, os dados não mudam."

---

## 5. Admins do jogo

**Objetivo:** ver, adicionar e remover admins do jogo. Só para admins do jogo. A barra inferior aparece.

**Conteúdo:**

1. Barra superior interna com o título **Admins do jogo**.
2. Lista dos admins, em ordem alfabética: avatar, nome e o subtítulo "Na lista" ou "Fora da lista". No exemplo: **Ana (você)**, "Na lista"; **Brunão**, "Fora da lista".
3. No pé, o botão principal **Adicionar admin**. Abre uma folha com o título "Quem vai ser admin?" e as pessoas da lista que ainda não são admins (no exemplo, a Carlinha). Sem ninguém, a frase "Só quem está na lista pode ser admin, e todos da lista já são."

**Toque numa linha:** em outra pessoa, folha com o nome como título e as opções **Ver perfil** e **Remover admin**. Em si mesma, com outro admin no jogo, a opção **Deixar de ser admin**, que pede confirmação: "Deixar de ser admin do jogo?" / "Só outro admin do jogo poderá devolver esse papel a você."

**Snackbars:** "Carlinha agora é admin do jogo.", "Brunão não é mais admin do jogo.", "Você não é mais admin deste jogo."

---

## 6. Detalhe do grupo, com os jogos

O Detalhe do grupo das telas de grupos ganha, entre as linhas (Integrantes, Solicitações, Convite, Editar grupo) e o botão **Sair do grupo**:

1. O título **Próximos jogos** e os cards dos jogos Abertos e Confirmados do grupo. No exemplo, os jogos 1 e 2.
2. O botão principal **Criar jogo**.

Sem jogos: a frase "Nenhum jogo marcado neste grupo."

A confirmação de **Sair do grupo** ganha uma segunda frase: "Você também sai da lista e da espera dos jogos do grupo que ainda não começaram, sem multa."

---

## 7. Aviso de que não dá para sair do grupo

**Objetivo:** explicar por que a pessoa não pode sair do grupo agora. Folha que abre sobre o Detalhe do grupo (ou sobre Integrantes, quando um admin tenta remover alguém).

**Conteúdo**, no exemplo da **Carla**, recebedora do jogo dela:

1. Título **Você ainda não pode sair do grupo**.
2. A frase "Você é o recebedor destes jogos, que ainda não foram concluídos. Para sair do grupo, os jogos precisam ser cancelados ou concluídos."
3. O card do jogo da Carla (Vôlei de Quinta, Arena Delta, ter 24/11 às 19:00). Tocar no card abre o detalhe do jogo.
4. Botão de contorno **Voltar**.

**Variações**, que só trocam o texto:

- Único admin: "Você é o único admin destes jogos. Indique outro admin em Admins do jogo antes de sair."
- Quando um admin do grupo tenta remover a Carla: título "Ainda não dá para remover Carlinha" e a frase "Carlinha é o recebedor destes jogos, que ainda não foram concluídos. Para remover, os jogos precisam ser cancelados ou concluídos."

---

## 8. Perfil de outra pessoa, com telefone

O Perfil de outra pessoa das telas de grupos ganha, abaixo do nome, quando a pessoa deixa o telefone visível:

1. A linha **Telefone** com "(86) 99999-8888".
2. Dois botões de contorno, lado a lado: **Ligar** e **WhatsApp**.

No exemplo, o perfil da Ana. Com o telefone oculto, nada aparece.

---

## Imagens a produzir

| Arquivo | Tela | Status |
|---------|------|--------|
| `games.png` | 1. Meus jogos, Próximos, com três jogos | Obrigatório |
| `games-anteriores.png` | 1. Meus jogos, Anteriores, com um jogo cancelado | Opcional |
| `games-vazio.png` | 1. Meus jogos, sem nenhum jogo | Opcional |
| `gamesNew.png` | 2. Criar jogo, preenchido | Obrigatório |
| `gamesNew-semPix.png` | 2. Criar jogo, sem chave Pix | Opcional |
| `game.png` | 3. Detalhe do jogo 1, visto pelo Brunão | Obrigatório |
| `game-admin.png` | 3. Detalhe do jogo 1, visto pela Ana, com o menu aberto | Obrigatório |
| `game-confirmado.png` | 3. Detalhe do jogo 2, visto por quem está fora, com o botão da espera | Obrigatório |
| `game-espera.png` | 3. Detalhe do jogo 2, visto pelo Brunão, na espera | Opcional |
| `game-andamento.png` | 3. Detalhe em andamento | Opcional |
| `game-cancelado.png` | 3. Detalhe cancelado | Opcional |
| `game-sair.png` | 3. Confirmação de saída depois do prazo | Opcional |
| `game-participante.png` | 3. Folha do admin sobre um participante | Opcional |
| `gameEdit.png` | 4. Editar jogo | Opcional |
| `gameAdmins.png` | 5. Admins do jogo | Obrigatório |
| `gameAdmins-adicionar.png` | 5. Folha de adicionar admin | Opcional |
| `group-jogos.png` | 6. Detalhe do grupo com os jogos | Obrigatório |
| `group-sairBloqueado.png` | 7. Aviso de que não dá para sair do grupo | Obrigatório |
| `person-telefone.png` | 8. Perfil de outra pessoa com telefone | Obrigatório |

Não é preciso desenhar os estados comuns (carregando, erro, sem internet, não encontrado, *snackbar*, erro de campo), salvo se quiser uma aparência diferente. As confirmações seguem o desenho da confirmação de saída do grupo.
