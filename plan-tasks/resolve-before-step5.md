# Plano — Resolver antes do passo 5

> Rodadas de perguntas interativas guiadas por este plano. Origem: varredura de 2026-11-03.

## Context

A varredura de 2026-11-03 (passo 4 fechado, oito suítes verdes, migrações local = remoto, migração `visoes` escrita mas não commitada) achou decisões abertas que o passo 5 teria de inventar: o mapa de tela para passo, a forma como o feed e os painéis leem número agregado, as ações de criador e admin que o desenho não mostra, e a base do app que ainda não existe (tema claro, fuso, navegação das quatro raízes). Pelo `CLAUDE.md`, lacuna de regra é decisão de produto: **documento fecha antes de código**, e o passo 5 não começa com decisão pendente.

Este plano registra a análise e a transforma em **rodadas de perguntas interativas na CLI** (`AskUserQuestion`, até 4 perguntas por rodada, 2–4 opções, a recomendada primeiro). Cada resposta vira texto normativo nos documentos, num commit só de documentação. Nenhuma tela, migração ou painel é tocado enquanto as rodadas correm.

Regras para a execução:
- Uma rodada por vez; a seguinte só abre com a anterior registrada no estado abaixo.
- Cada pergunta traz o trecho do PRD ou do `DESIGN.md` que a origina (RN/RF/id de tela) e a consequência de cada opção.
- Decisão abstrata vai com cenário concreto: personagens e tabela, nunca só o princípio.
- Resposta "Outra" do usuário vale como decisão; registre o texto dele, não uma paráfrase.
- No fim de cada rodada, cruze as respostas entre si: se duas decisões juntas criam um risco que nenhuma delas cria sozinha, volte a perguntar com o cenário.
- Entre duas opções equivalentes, prefira a que **elimina estado** em vez de acomodá-lo.
- Não inventar campo, enum, entidade, tela nem função fora do que o usuário aprovar na rodada.
- O PRD vence em divergência; `DESIGN.md`, `modelo-de-dados.md` e `stack.md` são ajustados para acompanhá-lo. Divergência entre desenho e PRD vai para o `implementacao.md` do grupo da tela.

## Estado

| Rodada | Tema | Estado |
| --- | --- | --- |
| R1 | Escopo: qual tela entra no passo 5 | a fazer |
| R2 | Leitura: agregados, feed e atualização | a fazer |
| R3 | Ações de jogo e de cobrança sem tela | a fazer |
| R4 | Pré-requisitos: migração `visoes`, locais do piloto, pacotes | a fazer |
| R5 | Bordas: o que de outros passos aparece na tela | a fazer |
| R6 | Textos de recusa e estados não desenhados | a fazer |
| R7 | Base técnica do app | a fazer |
| R8 | Aplicar nos documentos e fechar | a fazer |

## T0 — Preparação

1. Reler `docs/prd.md` (RF12–RF23, RF27, RF28, RF33, RF34, RN04, RN08, RN13, RN15, RN17, RN24, RN26), `docs/design/DESIGN.md` inteiro (seção Telas, Mapa de status, Componentes) e `docs/stack.md` (ordem de implementação, matriz de política de linha) antes de formular cada rodada.
2. Abrir com `Read` os PNGs citados na rodada da vez. Os textos exatos e os estados estão na imagem, não no documento.
3. Conferir o estado do trabalho não commitado: `supabase/migrations/20261103162455_visoes.sql`, `supabase/testes/visoes.sql` e os `.md` modificados.

---

## R1 — Escopo: qual tela entra no passo 5

O `stack.md` descreve o passo 5 numa frase ("feed, tela de jogo, criação, confirmação e cancelamento, painel de débitos e de recebimentos, H1, H2 e H4"). O `DESIGN.md` tem 36 telas, e várias não têm passo atribuído em documento nenhum. O resultado desta rodada é um **mapa tela → passo** no `stack.md`.

**Q1.1 Grupos D1–D5 (RF03, RF05, RF06, RF29, RF30, RF31; RN13).** As cinco RPCs de grupo existem desde o passo 4 e a navegação inferior tem uma aba fixa "Grupos" (`DESIGN.md`, Navegação inferior). Sem D1–D5 não há como criar grupo pelo app, e sem grupo o feed nasce vazio e o jogo de grupo não existe — só o avulso, que até o passo 9 tem só o criador.
- (Recomendada) **D1–D5 entram no passo 5.** O passo cresce em cinco telas, mas entrega o app utilizável de ponta a ponta: criar grupo, criar jogo nele, confirmar, cobrar.
- Só D1 e D4 (lista e novo grupo) no passo 5; D2, D3 e D5 num passo 5b.
- Grupos ficam fora do passo 5 e a aba abre um estado "em breve". O piloto roda com grupo criado à mão no Studio.

**Q1.2 B5, B6 e B7 (RF16, RF17, RF18; RN04, RN08).** Lista de espera, vaga liberada e marcar faltas dependem só de função já pronta. A janela de falta fecha 24 h depois do encerramento previsto e não volta: jogo que acontecer sem a B7 perde a marcação para sempre.
- (Recomendada) **As três entram no passo 5**, junto da tela de jogo.
- B5 e B6 no passo 5 (são estados da tela de jogo), B7 no passo 8, com as rotinas.
- As três ficam para depois do comprovante (passo 6).

**Q1.3 Onde o passo 5 corta as cobranças (RF20, RF21, RF22, RF23; RN07).** F1 e F6 são os painéis citados no passo. F2 é só leitura (valor, chave Pix copiável, rateio); F3, F4 e F5 são o envio do comprovante, claramente do passo 6; F7 mistura revisar comprovante (passo 6) com dar baixa e isentar (funções do passo 4).
- (Recomendada) **F1, F2 e F6 no passo 5**, mais a tela do credor para dar baixa e isentar (Q3.4). F3, F4, F5 e F7 no passo 6.
- Só F1 e F6 no passo 5; F2 vai junto com o envio, no passo 6, porque pagar e comprovar são o mesmo gesto.
- F1, F2, F6 e F7 inteira no passo 5, com a parte do comprovante desabilitada até o passo 6.

**Q1.4 Telas que o feed exige e o desenho não tem.** O B1 traz "Ver todos" ao lado de "Esta semana", e a B3 traz "+7 mais" sobre os avatares. Nenhuma das duas tem PNG nem id, e é atrás do "+7 mais" que mora a marca de débito vencido da RN26, que a `listar_participantes` já devolve.
- (Recomendada) **Duas telas novas sem PNG**, descritas no `implementacao.md` do grupo 02-jogos: lista de jogos (o "Ver todos", com os mesmos cards da semana) e lista de participantes (linha de pessoa do `DESIGN.md`, com o selo de status e a marca de vencido). Ganham id no `DESIGN.md` (B8 e B9).
- Sem telas novas: "Ver todos" rola a própria B1 e o "+7 mais" abre um sheet com a lista.
- "Ver todos" sai do B1 no passo 5 e a lista de participantes vira sheet.

### Respostas da R1 — (a preencher)

---

## R2 — Leitura: agregados, feed e atualização

O B1, o F1 e o F6 mostram número agregado que ninguém especificou, e hoje a única visão é a `cobranca_vencimento`. Esta rodada decide **o que cada número significa** e **onde ele é calculado**.

**Q2.1 De onde vêm os agregados (RNF08, RNF09; `stack.md`, Onde cada regra mora).** O B1 mostra `12/14` vagas por jogo; o F6 mostra "Falta receber", "Recebido", "58% pago" e agrupamento por pessoa; a aba Cobranças leva um selo com a contagem de débitos.

Cenário: a Ana abre o app com 6 jogos visíveis na semana e 9 cobranças.

| Caminho | Consultas no feed | Onde a regra mora |
| --- | --- | --- |
| Visões novas na migração `visoes` | 1 | banco |
| Contagem no app sobre `participacao` e `cobranca_vencimento` | 1 + 6 | app |

- (Recomendada) **Visões novas** (`jogo_feed` com vagas ocupadas e a participação de quem consulta; agregados de cobrança), `security_invoker`, na mesma migração `visoes`. Uma consulta por tela e nenhuma contagem no app.
- Contagem no app, sem visão nova: menos SQL, mais consultas e a definição do número espalhada pelas telas.
- Visão só para o feed; os painéis contam no app sobre `cobranca_vencimento`, que já traz tudo numa consulta.

**Q2.2 O que é "esta semana" e o que entra no feed (RF12, RF13).** O B1 diz "Sua semana tem 3 jogos", lista "Esta semana" e destaca um "Próximo jogo".
- (Recomendada) **Sete dias à frente da hora do servidor**, não semana de calendário; o feed traz jogo `aberto` que a pessoa vê (dela ou dos grupos dela), em ordem de início; "Próximo jogo" é o primeiro da lista, confirmada ou não (o selo diz qual é o caso).
- Semana de calendário (segunda a domingo), que casa com "sua semana" mas esvazia o feed no domingo à noite.
- Sete dias, mas "Próximo jogo" só aparece quando ela está confirmada; sem confirmação, o herói mostra o próximo jogo aberto com vaga.

**Q2.3 O universo dos painéis (RF20, RF21; RN07, RN19).** O F1 separa "Para pagar", "Aguardando o jogo" e "Resolvidas"; o F6 soma "Falta receber" e "Recebido" e mostra a porcentagem paga.
- (Recomendada) **Ativas sem horizonte, resolvidas dos últimos 30 dias** (a mesma janela da retenção da RNF03); "Você deve" e "Falta receber" somam só `pendente` e `comprovante_enviado`; isenta e cancelada não entram em soma nenhuma, e aparecem só na lista de resolvidas; "58% pago" é recebido ÷ (recebido + falta receber) no mesmo universo.
- Tudo, sem horizonte: o histórico inteiro na tela, que cresce sem limite.
- Resolvidas só do mês corrente.

**Q2.4 Como a tela se atualiza (RN08, RN29).** A vaga liberada é anunciada a todos e fica com quem confirmar primeiro; duas pessoas podem estar na B2 ao mesmo tempo.
- (Recomendada) **Recarga ao abrir a tela e ao voltar para ela, mais puxar para atualizar.** Sem assinatura, sem pacote novo, sem conexão aberta; a recusa do servidor é a fonte de verdade quando a vaga acabou.
- Realtime do Supabase nas telas de jogo: tela sempre fresca, uma conexão aberta por tela e um caminho novo no desenho de três peças, que hoje não o prevê.
- Recarga automática a cada N segundos enquanto a tela de jogo estiver aberta.

### Respostas da R2 — (a preencher)

---

## R3 — Ações de jogo e de cobrança sem tela

**Q3.1 As ações de criador e admin não estão na B2/B3 (RF10, RF11, RF33, RF34; RN13).** O PNG da B3 traz só "Cancelar presença" e "Convidar". Não há entrada para editar (C4), duplicar (C5), cancelar o jogo, encerrar à mão nem marcar faltas (B7) — todas com função pronta desde o passo 4.
- (Recomendada) **Menu de três pontos na barra do herói**, ao lado do compartilhar, com os itens que o papel e o estado do jogo permitem; o que não cabe não aparece. As duas pílulas do pé seguem sendo as do participante.
- Um bloco "Organização" no corpo da tela, abaixo de "Quem vai", visível só para criador e admin.
- Variante própria da tela para criador e admin, com outro pé.

**Q3.2 A B7 é em lote e a função é por pessoa (RF18, RN04, RNF10).** O botão diz "Marcar 1 falta" com vários checkboxes; `marcar_falta(jogo, pessoa)` marca uma pessoa por chamada e grava um aviso por marcação.

Cenário: o Thiago marca Heitor, Iara e Carla de uma vez. A chamada da Iara falha por rede.

| Caminho | Resultado | Aviso |
| --- | --- | --- |
| N chamadas em sequência | Heitor marcado, Iara não, Carla talvez | um por marcação que deu certo |
| RPC nova em lote | as três ou nenhuma | um por pessoa, na mesma transação |

- (Recomendada) **RPC nova em lote** (`marcar_faltas(jogo, pessoas[])`), numa migração de ajuste no início do passo 5, reaproveitando a lógica interna da `marcar_falta`. Tudo ou nada, e a tela não precisa contar sucesso parcial.
- N chamadas em sequência, com a tela mostrando o que deu certo e o que falhou.
- A tela deixa de ser em lote: um toque marca uma pessoa, com confirmação.

**Q3.3 Desmarcar falta (RN04).** O PNG da B7 mostra o Heitor com o checkbox ligado e o selo "Faltou", o que sugere poder desligar. Não existe função de desmarcar, e o PRD não prevê o caminho de volta: a RN04 diz que a marcação move a cobrança para origem `falta` "qualquer que seja o status dela".
- (Recomendada) **Desmarcar não existe.** O checkbox de quem já está marcado fica travado, e a tela diz que a marcação não se desfaz. Nenhuma regra nova, nenhum estado novo.
- Desmarcar existe dentro da janela de 24 h: regra nova na RN04, função nova, aviso novo e a volta da origem `falta` para `parte`.
- Desmarcar existe e não avisa ninguém, por ser correção de engano.

**Q3.4 Dar baixa e isentar sem comprovante (RF22, RF23; RN07, RN13).** As duas funções valem para qualquer cobrança liberada, mas a única tela do credor é a F7, "revisar comprovante". No F6, tocar numa pessoa que não enviou nada não leva a lugar definido.
- (Recomendada) **Tela nova de cobrança vista pelo credor**, sem PNG, descrita no `implementacao.md` do grupo 07-cobrancas e com id no `DESIGN.md` (F8): quem deve, quanto, de que jogo, e os botões "Dar baixa" e "Isentar". Quando houver comprovante, ela é a F7; sem comprovante, a mesma tela sem o bloco da imagem.
- Sheet a partir da linha do F6, com os dois botões e nada mais.
- Os dois botões direto na linha do F6, sem tela intermediária, com uma confirmação curta.

### Respostas da R3 — (a preencher)

---

## R4 — Pré-requisitos: migração `visoes`, locais do piloto, pacotes

**Q4.1 A migração `visoes` pertence a qual passo.** Ela está escrita, com suíte própria (`supabase/testes/visoes.sql`), e não foi commitada nem empurrada. Refaz por `create or replace` a `listar_participantes`, a `privado.encerrar` e a `marcar_falta`, e abre as duas puras de prazo para `authenticated`.
- (Recomendada) **Abertura do passo 5**, como `ajustes_funcoes` e `ajustes_schema` abriram o 4: commit próprio, suítes verdes, `db push`, e uma entrada no `progresso.md` sob o passo 5. Se a R2 pedir visões novas e a R3 uma RPC em lote, elas entram na mesma migração, antes de qualquer tela.
- Complemento do passo 4: reabre o passo fechado para registrar a unificação do prazo.
- Migração própria agora e outra para as visões do feed, depois da R2.

**Q4.2 Locais reais do piloto (RF27, RF28; RN14, RN15, RN18).** O `seed.sql` tem dois locais fictícios e o remoto não tem local nenhum. Sem local, quadra, horário de funcionamento, modo, capacidade e preço por hora reais, não dá para criar jogo nem montar E1 e E2 — e a checagem da RN15 nunca é exercida de verdade.
- (Recomendada) **O usuário levanta os locais reais do piloto** (nome, endereço, coordenadas, modo, capacidade, quadras, faixas de funcionamento e preço por hora) e eles entram no `seed.sql` e no remoto antes das telas C e E. Até lá, as telas se desenvolvem sobre o seed fictício, já no formato real.
- Seed fictício no local e nada no remoto até o passo 10: o piloto só testa com dado inventado.
- Um local real só, o principal da turma, agora; os demais quando houver.

**Q4.3 Pacotes e permissão de localização (RF28).** `intl`, `shared_preferences` e `geolocator` estão na lista do `stack.md` e não no `pubspec.yaml`. O geolocator traz permissão no manifesto e o caso de a pessoa negar.
- (Recomendada) **Os três entram no passo 5**; sem localização, a E1 ordena por nome e esconde a distância, sem bloquear nada, e a permissão só é pedida quando a E1 abre.
- `intl` e `shared_preferences` agora; `geolocator` e a ordenação por proximidade ficam para depois do piloto, com a E1 ordenando por nome.
- Os três entram, e a permissão é pedida na primeira abertura do app.

### Respostas da R4 — (a preencher)

---

## R5 — Bordas: o que de outros passos aparece na tela

**Q5.1 O sino e a G1 (RF38, RF40; passo 7).** O sino está na barra de **toda** tela raiz dos PNGs, com ponto de não lido, e abre a G1. Os avisos já são gravados em `notificacao` desde o passo 4, então a lista teria conteúdo real; o que falta no passo 7 é a entrega por push.
- (Recomendada) **Antecipar a G1 e o sino para o passo 5** (lista, ponto de não lido e marcar como lido, que é escrita direta em `notificacao`). O passo 7 fica só com gatilho, Edge Function, FCM e `registrar_dispositivo`.
- Sino visível e desabilitado até o passo 7, sem ponto.
- Sino fora da barra até o passo 7.

**Q5.2 "Avisos por push" na H1 (RF38, RN29).** O interruptor da H1 controla o registro do aparelho, que só existe no passo 7.
- (Recomendada) **A linha não aparece no passo 5** e entra com o passo 7, junto do `registrar_dispositivo`.
- Aparece desligada e desabilitada, com um texto curto dizendo que chega em breve.
- Aparece e guarda a escolha no aparelho, sem efeito algum até o passo 7.

**Q5.3 "Convidar" e o compartilhar da B3 (RF09, RN22; passo 9).** As duas dependem de `gerar_convite`.
- (Recomendada) **Os dois ficam fora da tela no passo 5.** O pé da B3 passa a ter só "Cancelar presença", em largura inteira.
- "Convidar" visível e desabilitado, com um aviso ao toque.
- Antecipar `gerar_convite` e o convite de jogo para o passo 5, trazendo parte do passo 9 junto.

**Q5.4 Foto de perfil (RF02).** A matriz da política já permite a escrita de `avatar_url`, mas a H1 e a H2 mostram só iniciais, e o espaço privado do Storage só aparece no passo 6.
- (Recomendada) **Avatar fica para o passo 6**, com o Storage; H1 e H2 usam as iniciais, como nos PNGs. Nenhuma tela do passo 5 escreve `avatar_url`.
- Antecipar o Storage e a foto para o passo 5, com bucket público de avatar.
- Avatar nunca entra no MVP; a RF02 é reescrita.

### Respostas da R5 — (a preencher)

---

## R6 — Textos de recusa e estados não desenhados

**Q6.1 Os códigos de recusa viram texto onde (`supabase/CLAUDE.md`, Funções).** São cerca de quarenta códigos estáveis (`quadra_ocupada`, `vagas_abaixo_dos_confirmados`, `recebedor_sem_chave`, `pagamento_nao_liberado`…) sem texto em português definido. O `DESIGN.md` só desenhou erro nas telas de acesso.
- (Recomendada) **Uma tabela código → texto no `08-avisos/implementacao.md`** (ou num `implementacao.md` novo, de mensagens), aprovada antes das telas, com um mapa único no app; o texto aparece no componente Aviso inline acima do botão primário, como nas telas A, e em sheet quando a ação vier de um sheet.
- Texto decidido tela a tela, junto de cada tela, sem tabela central.
- Mensagem genérica ("Não foi possível concluir") para tudo, menos uma dúzia de códigos que ganham texto próprio.

**Q6.2 Estados de vazio, carregamento e erro (`DESIGN.md`, Fora do design).** Não foram desenhados; o documento só diz que seguem o padrão do herói.
- (Recomendada) **Três peças em `lib/core/widgets/`** — vazio (ícone, título, linha de apoio e ação opcional), carregando (esqueleto dos blocos, não roda-roda de tela cheia) e erro de rede (texto e "Tentar de novo") — com os textos de cada tela aprovados junto das telas.
- Um padrão só, igual em toda tela, sem texto por tela.
- Cada tela resolve o seu, sem peça compartilhada.

**Q6.3 O feed da primeira abertura.** Quem acaba de criar a conta não tem grupo nem jogo, e o B1 inteiro depende de ter os dois. É a primeira tela do app de verdade.
- (Recomendada) **Vazio com duas saídas**: "Criar grupo" (D4) e "Criar jogo avulso" (C1/C3), que é o que existe no passo 5 sem convite.
- Vazio com uma saída só, "Criar grupo", porque o avulso sem convite tem só o criador.
- Vazio com texto explicando que falta um convite, sem ação.

**Q6.4 Quem aparece no seletor de recebedor (RN24, C2 e C3).** A regra fala em "escolher na lista de pessoas que já têm chave cadastrada", e a política de linha deixa a pessoa ler quem divide grupo com ela e quem está envolvido num jogo que ela vê. No avulso, o criador pode não ver ninguém.
- (Recomendada) **No jogo de grupo, os membros do grupo com chave; no avulso, só o criador ou uma chave digitada à mão** (RN24), que vale só para aquele jogo.
- Qualquer pessoa que a política deixa ler e que tenha chave, nos dois casos.
- Só o criador, nos dois casos; a troca de recebedor é sempre por chave digitada.

### Respostas da R6 — (a preencher)

---

## R7 — Base técnica do app

Decisões de implementação, não de produto: entram no `app/CLAUDE.md` e no `progresso.md`, não no PRD.

**Q7.1 Tema claro (`DESIGN.md`, Base clara; H1 "Aparência").** `tema.dart` só tem a base escura, e as telas A saíram escuras por decisão registrada no passo 3. A linha "Aparência" vive na H1, que é do passo 5.
- (Recomendada) **O passo 5 entrega o tema claro inteiro**, incluindo voltar às telas A, e toda tela nova nasce conferida nos dois modos, como manda o `app/CLAUDE.md`.
- Tema claro só no fim do passo 5, numa task própria, depois das telas.
- Fica só o escuro no MVP; a linha "Aparência" sai da H1 e o `DESIGN.md` registra a divergência.

**Q7.2 Fuso e formatos (RN02, RNF08).** `lib/core/fuso` está na estrutura prevista e não existe. Os formatos do `DESIGN.md` (`qui, 23 out`, `19:30`, `R$ 14,29`, `12/14`, `2 h 30`) ainda não têm um lugar no app, e o banco já tem os seus para os avisos.
- (Recomendada) **Deslocamento fixo de −03:00** (o Brasil não tem horário de verão desde 2019) num `fuso.dart`, com os formatos em `formatos.dart` sobre o `intl` em `pt_BR`, e nenhuma comparação de prazo no aparelho.
- Pacote de fuso horário completo (`timezone`), que não está na lista fechada e pede justificativa de tamanho.
- Usar o fuso do aparelho, aceitando que quem viaja veja hora errada.

**Q7.3 Navegação e camada de dados.** `rotas.dart` hoje serve ao fluxo de acesso e `inicio_tela.dart` é provisória. Faltam o invólucro das quatro raízes ("a navegação troca de raiz sem empilhar") e a convenção de repositório, modelo e Riverpod antes de dez telas fixarem dez jeitos.
- (Recomendada) **Uma task de base abrindo o passo 5**: invólucro das quatro raízes, `inicio_tela.dart` removida, "Trocar senha" movida para a H1, um repositório por agregado em `lib/dados/`, e o padrão de tradução de recusa (código → texto) num lugar só.
- Base feita junto da primeira tela, sem task própria.
- Base feita no fim, refatorando as telas prontas.

**Q7.4 O que fecha o passo 5.** Os passos 1 a 4 fecharam com suíte SQL verde. No app só há `flutter test` de widget e `dart analyze`.
- (Recomendada) **Três critérios**: `dart analyze` limpo e `flutter test` verde, com teste de widget para cada tela nova; conferência tela a tela contra o PNG, nos dois modos; e um roteiro manual no aparelho físico contra o remoto, do cadastro ao pagamento liberado, registrado como as T0x do passo 3.
- Só `dart analyze` e `flutter test`, com a conferência visual feita ao implementar cada tela.
- Os três, mais um teste de integração ponta a ponta no emulador, que exige infraestrutura nova.

### Respostas da R7 — (a preencher)

---

## R8 — Aplicar nos documentos e fechar

Sem perguntas novas: transforma as respostas em texto normativo, num commit só de documentação.

1. `docs/prd.md` — só o que mudar regra ou requisito (por exemplo, a existência ou não de desmarcar falta, Q3.3).
2. `docs/stack.md` — mapa tela → passo (R1), o passo 5 reescrito com as visões e a RPC em lote decididas (R2, R3), os pacotes (R4.3) e a ordem interna do passo (R7.3).
3. `docs/design/DESIGN.md` — ids das telas novas (R1.4, R3.4), a linha "Aparência" se mudar (R7.1), e o que sair da seção Telas.
4. `docs/design/telas/*/implementacao.md` — divergências em relação aos PNGs: ações de criador e admin na B2/B3, B7 travada, pé da B3 sem "Convidar", H1 sem "Avisos por push", feed vazio, tabela de textos de recusa.
5. `app/CLAUDE.md` — fuso, formatos, navegação, camada de dados, tradução de recusa.
6. `supabase/CLAUDE.md` — visões novas e a RPC em lote, se houver.
7. `docs/progresso.md` — uma entrada "Decisões de produto antes do passo 5", no modelo da que precede o passo 4: só o índice, com o texto normativo nos documentos acima.
8. Commit único de documentação, e só então a primeira task de código do passo 5.

### Resultado da R8 — (a preencher)
