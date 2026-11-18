# VoleiIn: conclusão do jogo, rateio e cobranças

## Sobre o app

O VoleiIn é um app Android, em português do Brasil, para grupos de vôlei. Ele organiza jogos e listas de presença, calcula a divisão do valor da quadra e acompanha os pagamentos por Pix entre os participantes. O app não processa pagamentos.

Este documento descreve as telas de **conclusão do jogo e rateio**: concluir o jogo marcando as faltas, ver a divisão do valor, isentar uma multa, trocar o recebedor, ver o próprio histórico no jogo e a aba **Cobranças**, com o total a pagar e o total a receber.

## Como a conclusão funciona

- Depois do horário de fim, um **admin do jogo** conclui o jogo. Se ninguém concluir, o app conclui sozinho **1 hora depois do fim**.
- Na conclusão, o admin pode **mudar o valor total** (só nessa hora) e **marcar quem faltou**. Quem saiu da lista depois do início já vem marcado como faltoso, e dá para desmarcar. O **recebedor nunca leva falta**.
- A **parte por vaga** é o valor total dividido pelo **limite de vagas**, arredondado para cima ao centavo. Ex.: R$ 250,00 ÷ 12 vagas = **R$ 20,84**.
- Cada pessoa que jogou paga a parte por vaga. Quem **faltou** paga uma **multa** do mesmo valor. Quem **saiu depois do prazo** de cancelamento também pode pagar multa, mas o app isenta automaticamente os primeiros a sair quando sobraram vagas no início do jogo.
- O **recebedor** não paga nada a si mesmo. O que não foi coberto pelos outros (a vaga dele, as vagas vazias e a sobra do arredondamento) fica **por conta do recebedor**. Antes de concluir, o admin vê esse valor.
- A conclusão é **definitiva**: depois dela, o total e as faltas não mudam. Dá só para isentar uma multa e trocar o recebedor.
- Cada valor a pagar tem um status: **Pendente** (amarelo), **Em análise** (azul), **Pago** (verde) e **Isento** (neutro). Nesta etapa, todo valor nasce **Pendente**. Pagar e enviar comprovante chegam numa próxima etapa do app.
- Quem está na lista vê **só o próprio valor**. O recebedor e os admins do jogo veem o **rateio completo**.

## Pessoas e jogo dos exemplos

- **Vôlei de Quinta**, o grupo. **Ana** é admin do grupo e do jogo e a **recebedora**. Os outros: **Brunão** (Bruno), **Carlinha** (Carla), **Davi**, **Edu**, **Fábio**, **Gabi**, **Hugo**, **Iara**, **João**, **Kátia** e **Lara**.
- **Jogo:** Vôlei de Quinta, **Quadra do Sesc**, **qui, 19/11**, das **20:00 às 22:00**, prazo de cancelamento **qui, 19/11, às 18:00**, valor total **R$ 250,00**, **12 vagas**.
- Antes do jogo, Brunão (18:10), Carlinha (18:30) e Davi (19:20) saíram da lista **depois do prazo**. No início havia **10 pessoas** na lista: Ana, Edu, Fábio, Gabi, Hugo, Iara, João, Kátia, Lara e mais uma, o **Marcos**. Sobraram 2 vagas, então o app isenta a multa do primeiro a sair (Brunão) e mantém as de Carlinha e Davi.
- Na conclusão, a Ana marca o **Edu** como faltoso.
- **Resultado:** parte por vaga **R$ 20,84**. 8 pessoas pagam a parte (Fábio, Gabi, Hugo, Iara, João, Kátia, Lara e Marcos), Edu paga **Multa por falta**, Carlinha e Davi pagam **Multa por cancelamento**: 11 × R$ 20,84 = **R$ 229,24** a receber. Por conta da Ana: R$ 250,00 − R$ 229,24 = **R$ 20,76**.

Nas listas, o app mostra o apelido e, se a pessoa não tiver, o nome.

## Regras gerais

As regras das telas de jogos continuam valendo: só modo escuro, largura de 360 dp, tom informal com "você", botões com verbo no infinitivo, área de toque de 48 × 48 dp, fonte do sistema em 150% sem nada cortado, um botão principal por tela, os tipos de botão, os avatares, o selo em pílula, a linha de lista, a folha (sheet), a confirmação, o aviso em linha, o topo colorido do jogo, o trio de números e os estados comuns.

**Fontes:** Montserrat nos títulos e nomes; **Bebas Neue só nos números** (valores, vagas, horários); Roboto no resto.

**Cores dos blocos grandes**, sempre com texto azul-marinho escuro (`#192853`):

| Cor | Hex | Significa |
|-----|-----|-----------|
| Amarelo | `#FFE14F` | Jogo Aberto, ação principal |
| Azul-claro | `#8EC5FF` | Rateio, parte por vaga, jogo Concluído |
| Verde-água | `#7CDCC8` | Você recebe, valor Pago |
| Coral | `#FF8F6B` | Você deve, multa, vagas sem ninguém |

**Selos do status do valor:** **Pendente** (amarelo), **Em análise** (azul, com ampulheta), **Pago** (verde), **Isento** (neutro). E o selo vermelho **Faltou**, na lista do jogo concluído.

**Componentes novos nesta etapa:**

- **Caixa de seleção** numa linha de pessoa, para marcar a falta.
- **Bloco de resumo do rateio:** linhas com rótulo à esquerda e valor em Bebas Neue à direita.
- **Atalhos dos totais** (aba Cobranças): dois blocos lado a lado, **A pagar** em coral e **A receber** em verde-água, cada um com o valor grande em Bebas Neue e uma linha de apoio.
- **Linha de valor:** avatar, nome, rótulo do tipo (Parte do jogo, Multa por falta, Multa por cancelamento), valor em Bebas Neue e o selo do status.
- **Contador vermelho** na aba Cobranças da barra inferior, com o número de valores a pagar.

**Barra inferior:** Jogos, Grupos, Cobranças e Perfil. Aparece no detalhe, no rateio e em Cobranças. A conclusão cobre a barra.

## Fluxo entre as telas

1. No **Detalhe do jogo** depois do fim, o admin toca em **Concluir jogo**, que abre a **Conclusão**.
2. Ao concluir, a tela vira o **Rateio**. O voltar leva ao detalhe, agora com o jogo **Concluído**.
3. No detalhe do jogo concluído, o card **Rateio** abre o Rateio.
4. Pelo menu de três pontos, o admin abre **Trocar recebedor**, antes ou depois da conclusão.
5. Na aba **Cobranças**, tocar numa linha abre o Rateio daquele jogo.

---

## 1. Detalhe do jogo depois do fim

**Visto pela Ana (admin).** O topo amarelo, com o selo discreto **Aguardando conclusão**. No pé, fixo, a frase "Se ninguém concluir, o app conclui sozinho 1 hora depois do fim." e o botão principal **Concluir jogo**. O menu de três pontos ganha **Concluir jogo** e **Trocar recebedor**.

Quem não é admin continua vendo no pé o aviso "A lista está travada até a conclusão do jogo."

## 2. Concluir jogo

**Objetivo:** concluir o jogo, mudando o total se precisar, marcando as faltas e vendo o rateio antes de confirmar.

**Conteúdo, de cima para baixo** (a tela rola):

1. Barra superior interna com o título **Concluir jogo**.
2. Resumo do jogo: "qui, 19/11 · 20:00 – 22:00 · Quadra do Sesc".
3. **Valor total do espaço**, com `R$` e o valor já preenchido (**R$ 250,00**), e a dica "Só dá para mudar agora. Depois da conclusão, nada é recalculado."
4. **Quem faltou?**: uma linha por pessoa da lista, com avatar, nome e uma caixa de seleção à direita. A Ana não aparece. No exemplo, todas desmarcadas, menos o **Edu**, marcado. Se alguém tivesse saído depois do início, viria marcado com a linha de apoio "Saiu às 20:30". Abaixo da lista: "O recebedor não leva falta."
5. **Rateio**, o bloco de resumo:
   - **Parte por vaga**: R$ 20,84 (em azul-claro);
   - **A receber**: R$ 229,24;
   - **Por conta de Ana**: R$ 20,76;
   - a linha "1 multa de cancelamento isentada: sobraram vagas."
6. No pé, fixo, o botão principal **Concluir jogo**.

**Variante com vagas vazias:** se o jogo tivesse só 6 pessoas, aparece no resumo um aviso em linha coral: "6 vagas ficaram sem ninguém. R$ 145,80 fica por conta de Ana."

**Confirmação** (folha, em tom normal): título "Concluir o jogo?", a frase "A conclusão é definitiva: depois dela, o valor total e as faltas não mudam, e cada pessoa passa a ter o valor a pagar." e os botões **Concluir** e **Voltar**.

## 3. Rateio, visto pela Ana (recebedora)

**Objetivo:** ver como o valor foi dividido e quem já pagou.

**Conteúdo, de cima para baixo:**

1. Barra superior interna com o título **Rateio**.
2. "qui, 19/11 · Quadra do Sesc" e o trio de números: **Total** R$ 250,00, **Vagas** 12, **Parte por vaga** R$ 20,84 (azul-claro).
3. Três totais: **Recebido** R$ 0,00 (verde-água), **Pendente** R$ 229,24 (coral) e **Por conta de Ana** R$ 20,76.
4. **Valores:** uma linha por pessoa que paga, em ordem alfabética: Carlinha (Multa por cancelamento), Davi (Multa por cancelamento), Edu (Multa por falta), Fábio, Gabi, Hugo, Iara, João, Kátia, Lara e Marcos (Parte do jogo), todas com R$ 20,84 e **Pendente**.
5. **Sem valor a pagar:** Ana, com o selo **Recebedor**, e Brunão, com "Multa isentada: sobraram vagas".

Tocar numa **multa Pendente** abre uma folha com o nome como título e a opção **Isentar multa**. Ela pede confirmação: "Isentar a multa de Edu?", "O valor deixa de ser cobrado e não pode voltar.", com os botões **Isentar multa** e **Voltar**. Depois, a linha do Edu vai para uma seção **Isentos** no fim, com o selo **Isento** e "Isentado por um admin".

## 4. Rateio, visto pelo Fábio (participante)

1. O mesmo cabeçalho e o mesmo trio.
2. **Seu valor:** "Parte do jogo", **R$ 20,84** grande, o selo **Pendente** e, embaixo, "Para Ana".
3. Nada mais: o participante não vê o valor dos outros.

Quem não tem valor vê, no lugar, "Você não tem valor a pagar neste jogo." e o motivo, por exemplo "Sua multa foi isentada: sobraram vagas."

## 5. Detalhe do jogo concluído

**Visto pela Carlinha**, que saiu depois do prazo e ficou com multa.

1. Topo **azul-claro**, com a pílula **Concluído**, sem selo de tempo.
2. Trio de números: **Vagas** 10/12, **Parte por vaga** R$ 20,84 (azul-claro) e **Total** R$ 250,00.
3. O recebedor, como antes.
4. **Sua participação**, um card com as linhas:
   - "Saiu qui, 19/11 às 18:30, fora do prazo";
   - no fim, a linha de valor: "Multa por cancelamento", R$ 20,84, **Pendente**.
5. Card **Rateio**, uma linha tocável com o valor dela e uma seta, que abre o Rateio.
6. A lista de presença, com o selo vermelho **Faltou** no Edu. Sem lista de espera e sem botão no pé.

Outras linhas possíveis do card **Sua participação**: "Saiu ... no prazo", "Não conta: você voltou às 19:00", "Multa isentada: sobraram vagas", "Saiu às 20:30, depois do início", "Removido por um admin em ...", "Saiu do grupo em ...", "Falta marcada na conclusão". O card só aparece quando há alguma dessas linhas ou um valor a pagar.

## 6. Trocar recebedor

**Folha** sobre o detalhe, aberta pelo menu do admin.

1. Título **Trocar recebedor**.
2. A explicação. **Antes da conclusão:** "O novo recebedor precisa estar na lista e ter uma chave Pix. Os valores do jogo serão devidos a ele." **Depois da conclusão:** "Os valores já pagos continuam com o recebedor atual, e os pendentes passam ao novo. O valor do novo recebedor é anulado, e o recebedor atual passa a pagar a parte dele. O acerto do que já foi pago fica entre os dois, fora do app."
3. Uma linha por pessoa da lista, menos a recebedora atual. Tocar numa pessoa pede confirmação: "Trocar o recebedor para Fábio?", com **Trocar** e **Voltar**.
4. Sem ninguém para escolher: "Ninguém mais na lista pode ser o recebedor."

Desenhe a versão **depois da conclusão**.

## 7. Cobranças

**Objetivo:** ver o total a pagar e a receber, somando todos os jogos. É a tela da aba **Cobranças**: a barra inferior aparece, com Cobranças ativo.

**Vista pela Carlinha**, que deve a multa do jogo de quinta e R$ 15,00 ao Brunão num jogo de sábado, e é recebedora de um jogo da terça em que três pessoas lhe devem R$ 10,00 cada.

1. Barra superior de tela principal, com o título **Cobranças** grande.
2. Os dois atalhos: **A pagar** R$ 35,84 (coral), "em 2 jogos"; **A receber** R$ 30,00 (verde-água), "de 3 pessoas".
3. **A pagar**, uma linha por valor, do jogo mais antigo para o mais novo:
   - "qui, 19/11 · Quadra do Sesc", embaixo "Para Ana · Multa por cancelamento", à direita R$ 20,84 e **Pendente**;
   - "sáb, 21/11 · Ginásio Verdão", embaixo "Para Brunão", à direita R$ 15,00 e **Pendente**.
4. **A receber**, uma linha por jogo: "ter, 24/11 · Arena Delta", embaixo "3 pessoas", à direita R$ 30,00.
5. Na barra inferior, o contador vermelho **2** na aba Cobranças.

**Sem nada a pagar:** a seção mostra "Você não deve nada." **Sem nada a receber:** "Ninguém te deve." **Sem nenhum dos dois:** um ícone de dinheiro, o título "Tudo certo por aqui" e a frase "Quando um jogo for concluído, os valores aparecem aqui."

## Imagens a produzir

| Arquivo | Tela | Status |
|---------|------|--------|
| `game-aguardando.png` | 1. Detalhe depois do fim, visto pela Ana, com o botão Concluir jogo | Obrigatório |
| `gameComplete.png` | 2. Concluir jogo, com o Edu marcado e o resumo | Obrigatório |
| `gameComplete-vagas.png` | 2. Concluir jogo com o aviso de vagas vazias | Opcional |
| `gameComplete-confirmar.png` | 2. Confirmação da conclusão | Opcional |
| `gameSplit-recebedor.png` | 3. Rateio visto pela Ana | Obrigatório |
| `gameSplit-isentar.png` | 3. Folha de isentar a multa | Opcional |
| `gameSplit.png` | 4. Rateio visto pelo Fábio | Obrigatório |
| `game-concluido.png` | 5. Detalhe concluído visto pela Carlinha, com Sua participação | Obrigatório |
| `game-trocarRecebedor.png` | 6. Folha de trocar recebedor, depois da conclusão | Obrigatório |
| `charges.png` | 7. Cobranças vista pela Carlinha | Obrigatório |
| `charges-vazio.png` | 7. Cobranças sem nenhum valor | Opcional |

Não é preciso desenhar os estados comuns (carregando, erro, sem internet, não encontrado, *snackbar*, erro de campo), salvo se quiser uma aparência diferente. As confirmações seguem o desenho das confirmações da fatia 4.
