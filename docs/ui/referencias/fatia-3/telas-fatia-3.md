# VoleiIn: telas de grupos

## Sobre o app

O VoleiIn é um app Android, em português do Brasil, para grupos de vôlei. Ele organiza jogos e listas de presença, calcula a divisão do valor da quadra e acompanha os pagamentos por Pix entre os participantes. O app não processa pagamentos.

Este documento descreve as telas de **grupos**: ver os próprios grupos, criar um grupo, pedir para entrar com um código de convite, compartilhar o código, ver e administrar os integrantes, aprovar quem pediu para entrar, editar e excluir o grupo, e ver o perfil de outra pessoa.

## Como os grupos funcionam

- Quem **cria** o grupo vira **admin**. O grupo pode ter vários admins, e qualquer admin promove membros e rebaixa outros admins. O grupo sempre tem pelo menos um admin.
- Cada grupo tem um **código de convite** de 12 letras e números, como `VoleiQuinta1`. **O código diferencia maiúsculas de minúsculas**: `voleiquinta1` não vale.
- **Todo membro** vê, copia e compartilha o código. Só os **admins** geram um código novo (o antigo deixa de valer) ou desativam o convite.
- Quem tem o código **pede para entrar**. O pedido (a "solicitação") fica pendente até um admin aprovar ou recusar. Depois de uma recusa, a pessoa pode pedir de novo.
- Quem pediu só vê o grupo depois de aprovado. Até lá, o grupo não aparece na lista dela.
- O admin vê o nome e a foto de quem pediu, enquanto o pedido está pendente.
- Os jogos do grupo ainda não fazem parte destas telas: eles entram numa próxima etapa, no detalhe do grupo.

## Pessoas e grupos dos exemplos

Use estes dados nas imagens:

- **Vôlei de Quinta**, com foto, código `VoleiQuinta1`. Integrantes:
  - **Ana**, admin. É quem está usando o app na maior parte dos exemplos;
  - **Bruno**, com o apelido **Brunão**, membro;
  - **Carla**, com o apelido **Carlinha**, membro.
- **Areia do Rio**, sem foto, com 5 integrantes, em que a Ana é só membro.
- **Diego**, que ainda não está em nenhum grupo e pede para entrar no Vôlei de Quinta.

Nas listas, o app mostra o apelido e, se a pessoa não tiver, o nome.

## Regras gerais

- **Celular Android, só modo escuro.** Largura de referência: 360 dp.
- **Tom dos textos:** informal, curto, tratando por "você". Sem termos técnicos e sem exclamação em mensagens de erro. Os botões usam verbo no infinitivo ("Criar grupo", "Aprovar").
- **Textos:** os que aparecem entre aspas ou em negrito neste documento são os textos finais da tela.
- **Acessibilidade:** toda área de toque tem pelo menos 48 × 48 dp. As telas precisam funcionar com a fonte do sistema em 150%, sem nada cortado ou sobreposto, e rolam quando o teclado abre. Erro nunca é indicado só pela cor: o campo com erro mostra ícone e mensagem abaixo.
- **Um botão principal por tela.** As outras ações são botões de contorno ou de texto. A exceção é a tela de Solicitações, em que cada linha tem a sua ação de aprovar.
- **Tipos de botão:**
  - principal: preenchido, com a cor de destaque;
  - contorno: só a borda;
  - texto: sem fundo, parece um link;
  - destrutivo de contorno: borda neutra e texto avermelhado;
  - destrutivo sólido: fundo vermelho, usado só na confirmação final de algo destrutivo.
- **Avatar de pessoa:** círculo com a foto ou, sem foto, as iniciais sobre um fundo pastel. A própria pessoa ("você") tem o avatar amarelo.
- **Avatar de grupo:** **quadrado de cantos arredondados**, com a foto ou, sem foto, as iniciais do nome sobre um fundo pastel. É o que diferencia um grupo de uma pessoa.
- **Selo Admin:** uma pílula neutra, discreta, ao lado direito do nome.
- **Linha de lista:** avatar à esquerda, nome em negrito, um subtítulo menor embaixo e, quando for tocável para abrir outra tela, uma seta à direita.
- **Folha (sheet):** abre de baixo, com os cantos de cima arredondados e uma alça no topo.
- **Confirmação destrutiva:** uma folha com título, uma frase sobre a consequência, o botão destrutivo sólido e o botão de contorno **Voltar**.
- **Estados comuns**, que valem para todas as telas:
  - **Enviando:** o botão tocado troca o texto por um indicador de progresso e bloqueia novo toque.
  - **Erro de uma ação:** aparece uma mensagem flutuante na parte de baixo da tela (*snackbar*), e a tela continua como estava.
  - **Erro de um campo:** a borda fica com a cor de erro, com um ícone e a mensagem abaixo do campo.
  - **Carregando dados:** indicador circular no centro.
  - **Falha ao carregar ou sem internet:** ícone, uma frase e o botão **Tentar de novo**, no lugar do conteúdo.
  - **Não encontrado:** quando a pessoa abre um grupo do qual não é membro, ou um grupo excluído. Ícone e a frase "Não encontramos o que você procura."
  - **Atualizar:** as listas e o detalhe do grupo atualizam ao puxar a tela para baixo.
- **Rótulo dos campos** acima do campo, fora dele.
- **Barra superior interna:** botão circular de voltar à esquerda e o título da tela.
- **Barra inferior:** quatro abas, nesta ordem: **Jogos**, **Grupos**, **Cobranças** e **Perfil**. Aparece nas telas de Grupos marcadas abaixo, com a aba **Grupos** ativa. As telas de criação e de edição cobrem a barra.

## Fluxo entre as telas

1. A aba **Grupos** abre em **Meus grupos**.
2. Em Meus grupos, a pessoa pode:
   - tocar num grupo, que abre o **Detalhe do grupo**;
   - tocar em **Criar grupo**, que abre a **Criação**. Depois de criar, o app abre o Detalhe do grupo novo;
   - tocar em **Entrar com código**, que abre a **Entrada por código**.
3. No **Detalhe do grupo**, a pessoa chega a:
   - **Integrantes**, que leva ao **Perfil de outra pessoa**;
   - **Solicitações** (só admin), que também leva ao Perfil de quem pediu;
   - **Convite**, uma folha sobre o detalhe;
   - **Editar grupo** (só admin), onde também se exclui o grupo;
   - **Sair do grupo**, que volta a Meus grupos.

---

## 1. Meus grupos

**Objetivo:** ver os grupos de que a pessoa participa e chegar à criação e à entrada por código. É a tela da aba **Grupos**: **a barra inferior aparece**, com Grupos ativo.

**Conteúdo, de cima para baixo:**

1. Barra superior de tela principal, com o título **Grupos** grande, sem botão de voltar.
2. Lista dos grupos, em ordem alfabética. Cada linha:
   - avatar quadrado do grupo, de 44 dp;
   - o nome do grupo;
   - o subtítulo com o número de integrantes: "1 integrante" ou "5 integrantes";
   - para quem é **admin** do grupo: o selo **Admin** à direita e, se houver pedidos pendentes, o número deles no subtítulo: "3 integrantes · 2 solicitações".

   No exemplo, a Ana vê:
   - **Areia do Rio**, sem foto, "5 integrantes", sem selo;
   - **Vôlei de Quinta**, com foto, "3 integrantes · 2 solicitações", com o selo **Admin**.
3. No pé da tela, fixos: o botão principal **Criar grupo** e o botão de contorno **Entrar com código**.

**Sem nenhum grupo:** no lugar da lista, um ícone de grupos, o título "Você ainda não está em nenhum grupo" e a frase "Crie um grupo ou peça para entrar com o código de convite." Os dois botões do pé continuam.

---

## 2. Criar grupo

**Objetivo:** criar um grupo com nome e, se quiser, foto. Quem cria vira admin.

**Conteúdo:**

1. Barra superior interna com o título **Criar grupo**.
2. Avatar quadrado de 96 dp, com as iniciais do nome que está sendo digitado (ou um ícone de grupo, com o nome vazio), e o botão de texto **Escolher foto**. A foto escolhida aparece no avatar antes de criar.
3. Campo **Nome do grupo**.
4. Botão principal **Criar grupo**.

**Folha da foto**, que abre de baixo ao tocar em Escolher foto, sem título: as opções **Escolher da galeria**, **Tirar foto** e, se já houver foto escolhida, **Remover foto**. É a mesma folha da foto do perfil.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nome vazio | "Informe o nome do grupo." |
| Nome com mais de 60 caracteres | "O nome pode ter até 60 caracteres." |
| Foto acima de 2 MB | *Snackbar*: "A foto passa de 2 MB. Escolha outra." |
| Foto que não é JPEG, PNG ou WebP | *Snackbar*: "Use uma foto JPEG, PNG ou WebP." |
| Sucesso | Abre o Detalhe do grupo novo, com o *snackbar* "Grupo criado." O voltar não retorna à criação |
| O grupo foi criado, mas a foto não foi salva | Abre o Detalhe do grupo do mesmo jeito, com o *snackbar* "Grupo criado, mas a foto não foi salva. Tente de novo em Editar grupo." |
| Voltar sem criar | O que foi digitado é descartado, sem pedido de confirmação |

---

## 3. Entrar com código

**Objetivo:** pedir para entrar num grupo com o código de convite. A tela tem **duas etapas**, sem trocar de tela.

**Barra superior interna** com o título **Entrar com código**. Na etapa 2, o voltar leva de volta à etapa 1.

**Etapa 1:**

1. Frase: "Digite ou cole o código que você recebeu do grupo."
2. Campo **Código do convite**: texto, sem correção automática e sem maiúscula automática. No exemplo, `VoleiQuinta1`. Como o código diferencia maiúsculas de minúsculas, use uma fonte em que dê para ver a diferença entre elas.
3. Botão principal **Continuar**.

**Etapa 2, a prévia do grupo:**

1. Avatar quadrado de 96 dp e o nome do grupo: **Vôlei de Quinta**.
2. Embaixo, um destes três estados:

   | Estado | Conteúdo |
   |--------|----------|
   | **Pode pedir** (o caso normal) | A frase "Um admin do grupo precisa aprovar a sua entrada." e o botão principal **Pedir para entrar** |
   | **Pedido pendente** (a pessoa já pediu e ainda não foi decidido) | Um aviso em destaque, com um quadrado de ícone de ampulheta em lilás: "Solicitação enviada. Aguardando a aprovação de um admin." Abaixo, a frase "O grupo aparece em Meus grupos quando a solicitação for aprovada." e o botão de contorno **Voltar aos grupos**. Não há botão principal |
   | **Já é membro** | A frase "Você já é membro deste grupo." e o botão principal **Abrir o grupo** |

3. Em todos os estados, o botão de texto **Usar outro código**, que volta à etapa 1 com o campo limpo.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Código vazio | "Informe o código." |
| Código que não tem 12 letras e números | "O código tem 12 letras e números. Confira e tente de novo." |
| Código que não existe ou foi desativado | Erro no campo: "Este código não vale. Confira ou peça um novo ao grupo." |
| Pedir para entrar | A prévia passa ao estado **Pedido pendente** |
| Abrir o grupo | Abre o Detalhe do grupo |
| Voltar aos grupos | Volta a Meus grupos |

---

## 4. Detalhe do grupo

**Objetivo:** ver o grupo e chegar a integrantes, solicitações, convite e edição. **A barra inferior aparece**, com Grupos ativo.

**Conteúdo, de cima para baixo:**

1. Barra superior interna, com o botão de voltar.
2. Cabeçalho: avatar quadrado de 72 dp e o nome do grupo em destaque, **Vôlei de Quinta**.
3. Lista de linhas tocáveis, cada uma com uma seta à direita:
   - **Integrantes**, com o subtítulo "3 pessoas";
   - **Solicitações**, só para admin, com o subtítulo "2 solicitações pendentes", "1 solicitação pendente" ou "Nenhuma solicitação pendente";
   - **Convite**, com o subtítulo "Código ativo" ou "Convite desativado". Abre a folha do convite;
   - **Editar grupo**, só para admin, com o subtítulo "Nome e foto".
4. Botão destrutivo de contorno **Sair do grupo**. Não aparece quando a pessoa é o único membro do grupo: nesse caso, ela exclui o grupo em Editar grupo.

Deixe espaço abaixo das linhas: numa próxima etapa, o detalhe ganha os jogos do grupo e o botão Criar jogo.

**Variante: visto por um membro (Bruno).** A mesma tela, **sem** as linhas Solicitações e Editar grupo.

**Confirmação de saída**, uma folha que abre de baixo:

- título: **Sair do grupo Vôlei de Quinta?**;
- frase: "Para voltar, você vai precisar do código e da aprovação de um admin.";
- botão destrutivo sólido **Sair do grupo**;
- botão de contorno **Voltar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Sai do grupo | Volta a Meus grupos, sem o grupo, com o *snackbar* "Você saiu do grupo." |
| É o último admin e há outros membros | *Snackbar*: "Promova outro admin antes. O grupo precisa de ao menos um." |

---

## 5. Convite do grupo

**Objetivo:** ver, copiar e compartilhar o código. O admin também gera um código novo ou desativa o convite. É uma **folha** que abre de baixo, sobre o Detalhe do grupo.

**Com o código ativo:**

1. Título: **Convite do grupo**.
2. Frase: "Quem tiver o código pode pedir para entrar. Um admin aprova cada solicitação."
3. O código em destaque: **`VoleiQuinta1`**. Use uma fonte que mostre a diferença entre maiúsculas e minúsculas. **Não use uma fonte só de maiúsculas.**
4. Botão principal **Compartilhar**: abre o compartilhamento do Android (WhatsApp e outros) com o texto "Entre no grupo Vôlei de Quinta no VoleiIn. No app, toque em Grupos, depois em Entrar com código, e use o código: VoleiQuinta1".
5. Botão de contorno **Copiar código**: copia só o código e mostra o *snackbar* "Código copiado."
6. Só para admin, dois botões de texto: **Gerar novo código** e **Desativar convite**, este em tom destrutivo.

**Variante: vista por um membro (Bruno).** A mesma folha, **sem** Gerar novo código e Desativar convite.

**Com o convite desativado:**

1. Título: **Convite do grupo**.
2. Frase: "O convite está desativado."
3. Para admin: o botão principal **Gerar código**, sem pedido de confirmação.
4. Para membro: a frase "Peça a um admin para gerar um novo código.", sem botão.

**Confirmação de Gerar novo código**, uma folha:

- título: **Gerar um novo código?**;
- frase: "O código atual deixa de funcionar. As solicitações já feitas continuam valendo.";
- botão destrutivo sólido **Gerar novo código**;
- botão de contorno **Voltar**.

**Confirmação de Desativar convite**, uma folha:

- título: **Desativar o convite?**;
- frase: "Ninguém consegue pedir para entrar até um admin gerar um novo código. As solicitações já feitas continuam valendo.";
- botão destrutivo sólido **Desativar**;
- botão de contorno **Voltar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Gera um novo código | A folha mostra o código novo, com o *snackbar* "Novo código gerado." |
| Desativa o convite | A folha passa ao estado desativado, com o *snackbar* "Convite desativado." |
| Gera código com o convite desativado | A folha mostra o código |

---

## 6. Integrantes

**Objetivo:** ver quem está no grupo. O admin também promove, rebaixa e remove. **A barra inferior aparece**, com Grupos ativo.

**Conteúdo:**

1. Barra superior interna com o título **Integrantes**.
2. Lista dos membros: primeiro os admins, depois os demais, cada parte em ordem alfabética. Cada linha:
   - avatar circular de 44 dp;
   - o nome; a própria pessoa aparece com "(você)" depois do nome;
   - o subtítulo com a data de entrada: "Entrou em 02/11/2026";
   - o selo **Admin** à direita, para os admins.

   No exemplo, a Ana vê:
   - **Ana (você)**, com o avatar amarelo, "Entrou em 02/11/2026" e o selo **Admin**;
   - **Brunão**, "Entrou em 05/11/2026";
   - **Carlinha**, "Entrou em 09/11/2026".

**O que acontece ao tocar numa linha:**

| Quem toca | Em quem | O que abre |
|-----------|---------|------------|
| Membro | Outra pessoa | O Perfil da pessoa |
| Membro | Em si | Nada: a linha não é tocável |
| Admin | Outra pessoa | A folha de ações |
| Admin | Em si | A folha com a opção **Deixar de ser admin** |

**Folha de ações do admin**, que abre de baixo, com o nome da pessoa como título (no exemplo, **Brunão**) e as opções:

- **Ver perfil**;
- **Tornar admin**, se a pessoa é membro, ou **Deixar como membro**, se ela já é admin;
- **Remover do grupo**, em tom destrutivo.

**Confirmação de remoção**, uma folha:

- título: **Remover Brunão do grupo?**;
- frase: "Brunão deixa de ver o grupo. Para voltar, vai precisar do código e da aprovação de um admin.";
- botão destrutivo sólido **Remover**;
- botão de contorno **Voltar**.

**Confirmação de Deixar de ser admin**, uma folha:

- título: **Deixar de ser admin?**;
- frase: "Só outro admin poderá devolver esse papel a você.";
- botão destrutivo sólido **Deixar de ser admin**;
- botão de contorno **Voltar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Tornar admin | Sem confirmação. *Snackbar*: "Brunão agora é admin." O selo aparece na linha |
| Deixar como membro | Sem confirmação. *Snackbar*: "Brunão agora é membro." |
| Remover, depois de confirmar | *Snackbar*: "Removemos Brunão do grupo." A linha sai da lista |
| Deixar de ser admin, depois de confirmar | *Snackbar*: "Você agora é membro." A tela passa à versão de membro |
| O último admin tenta deixar de ser admin | *Snackbar*: "Promova outro admin antes. O grupo precisa de ao menos um." |

---

## 7. Solicitações

**Objetivo:** aprovar ou recusar quem pediu para entrar. Só para admin. **A barra inferior aparece**, com Grupos ativo.

**Conteúdo:**

1. Barra superior interna com o título **Solicitações**.
2. Lista dos pedidos pendentes, dos mais antigos para os mais novos. Cada linha:
   - avatar circular de 44 dp e o nome de quem pediu (no exemplo, **Diego** e uma segunda pessoa);
   - o subtítulo "Pediu em qui, 12/11";
   - duas ações: **Recusar**, de contorno, e **Aprovar**, preenchida.

   Tocar no avatar ou no nome abre o Perfil da pessoa.

**Sem pedidos:** no lugar da lista, um ícone de pessoa com "+", o título "Nenhuma solicitação pendente" e a frase "Quando alguém pedir para entrar com o código, a solicitação aparece aqui."

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Aprovar | A linha sai, com o *snackbar* "Diego entrou no grupo." |
| Recusar | Sem confirmação, porque a pessoa pode pedir de novo. A linha sai, com o *snackbar* "Solicitação recusada." |
| Outro admin decidiu antes | *Snackbar*: "Esta solicitação já foi decidida." A lista atualiza |
| Enviando | Os dois botões da linha ficam bloqueados, e o tocado mostra o indicador de progresso. As outras linhas continuam livres |

---

## 8. Editar grupo

**Objetivo:** editar o nome e a foto do grupo, e excluir o grupo. Só para admin. Nome e foto são gravados juntos, no botão Salvar.

**Conteúdo:**

1. Barra superior interna com o título **Editar grupo**.
2. Avatar quadrado de 96 dp com o botão de texto **Trocar foto**. A foto escolhida aparece no avatar antes de salvar. A folha da foto é a mesma da criação, com **Remover foto** quando houver foto.
3. Campo **Nome do grupo**.
4. Botão principal **Salvar**.
5. Botão destrutivo de contorno **Excluir grupo**.

**Confirmação de exclusão**, uma folha:

- título: **Excluir o grupo Vôlei de Quinta?**;
- frase: "Todos os integrantes saem do grupo, as solicitações pendentes são canceladas e o convite deixa de valer. Os jogos concluídos e cancelados continuam no histórico de quem participou.";
- botão destrutivo sólido **Excluir grupo**;
- botão de contorno **Voltar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nome vazio ou com mais de 60 caracteres | "Informe o nome do grupo." / "O nome pode ter até 60 caracteres." |
| Foto acima de 2 MB ou fora do formato | Os mesmos *snackbars* da criação |
| Salvar com sucesso | *Snackbar*: "Grupo salvo." Volta ao Detalhe do grupo |
| Excluir, depois de confirmar | Volta a Meus grupos, sem o grupo, com o *snackbar* "Grupo excluído." |
| O grupo tem jogos Abertos ou Confirmados | *Snackbar*: "O grupo ainda tem jogos Abertos ou Confirmados." O grupo continua |
| Voltar sem salvar | As alterações são descartadas, sem pedido de confirmação |

---

## 9. Perfil de outra pessoa

**Objetivo:** ver o apelido, o nome e a foto de outra pessoa. Abre a partir de Integrantes ou de Solicitações. **A barra inferior aparece**, com Grupos ativo.

**Conteúdo:**

1. Barra superior interna, com o botão de voltar.
2. Avatar circular de 96 dp.
3. O nome exibido em destaque: **Brunão**.
4. Embaixo, em tom secundário, o nome: **Bruno**. Só aparece quando a pessoa tem apelido.

Deixe espaço abaixo: numa próxima etapa, a tela ganha o telefone, quando a pessoa o deixa visível.

**Comportamento:** quem não divide um grupo nem um jogo com a pessoa vê o estado **Não encontrado**.

---

## Imagens a produzir

Uma imagem por tela ou variante, com estes nomes:

| Arquivo | Tela | Status |
|---------|------|--------|
| `groups.png` | 1. Meus grupos, com dois grupos | Obrigatório |
| `groups-vazio.png` | 1. Meus grupos, sem nenhum grupo | Opcional |
| `groupsNew.png` | 2. Criar grupo | Obrigatório |
| `groupsJoin-etapa1.png` | 3. Entrar com código, etapa 1 | Obrigatório |
| `groupsJoin-etapa2.png` | 3. Entrar com código, prévia com Pedir para entrar | Obrigatório |
| `groupsJoin-pendente.png` | 3. Entrar com código, prévia com o pedido pendente | Obrigatório |
| `groupsJoin-membro.png` | 3. Entrar com código, prévia de quem já é membro | Opcional |
| `group.png` | 4. Detalhe do grupo, visto pela admin | Obrigatório |
| `group-membro.png` | 4. Detalhe do grupo, visto por um membro | Obrigatório |
| `group-sair.png` | 4. Confirmação de saída | Opcional |
| `group-convite.png` | 5. Convite do grupo, visto pela admin | Obrigatório |
| `group-convite-membro.png` | 5. Convite do grupo, visto por um membro | Obrigatório |
| `group-convite-desativado.png` | 5. Convite desativado, visto pela admin | Opcional |
| `groupMembers.png` | 6. Integrantes | Obrigatório |
| `groupMembers-acoes.png` | 6. Folha de ações do admin | Obrigatório |
| `groupRequests.png` | 7. Solicitações | Obrigatório |
| `groupEdit.png` | 8. Editar grupo | Obrigatório |
| `person.png` | 9. Perfil de outra pessoa | Obrigatório |

Não é preciso desenhar os estados comuns (carregando, erro, sem internet, não encontrado, *snackbar*, erro de campo), salvo se quiser uma aparência diferente do padrão descrito em "Regras gerais". As confirmações que não estão na lista seguem o mesmo desenho da confirmação de remoção da chave Pix da fatia 2.
