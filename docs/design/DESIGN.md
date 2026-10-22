# Design — VoleiIn

Design system do app Android, versão 2. Vale para toda tela nova e para a reescrita das telas do passo 3 em diante. Substitui o tema atual de `app/lib/core/tema.dart` (`colorSchemeSeed: 0xFF1E88E5`, Material 3 padrão).

Este documento é a versão textual e normativa do design. As imagens de `telas/` são **referências visuais**: mostram cada tela com o id usado aqui (A1, B3, F2…) e os textos exatos. As telas são recriadas em Flutter a partir delas e deste documento.

As imagens seguem o padrão `telas/<grupo>/<id>-<nome>.png`, uma tela por imagem, no tema escuro (ex.: `telas/acesso/a1-acesso.png`). A pasta é preenchida aos poucos, grupo a grupo; a cobertura atual está na tabela de [Telas](#telas).

**Fidelidade alta.** Cores, tipografia, raios, espaçamentos e textos são finais. Nomes, valores e datas das telas são exemplos.

**Precedência.** O design decide aparência e texto. Ele não decide regra. Se uma tela mostra um comportamento que diverge do [PRD](../prd.md), vale o PRD, e a divergência é registrada em "Decisões de implementação" no fim deste documento.

## Princípios

- **A cor diz o que é.** Amarelo é jogo e ação, coral é o que você deve, menta é o que você recebe, lilás é espera e céu é rateio ainda não liberado. A mesma cor significa a mesma coisa em todas as telas.
- **Número grande, frase curta.** Valores, horários e vagas aparecem em Bebas Neue, grandes o bastante para ler de relance na quadra. O texto ao lado explica em uma linha.
- **Dinheiro sem ambiguidade.** Sempre "R$" com centavos, sempre com quem recebe e o prazo. Status de cobrança sempre com texto, nunca só com cor.
- **Sem punição visual.** Débito vencido é uma marca discreta, vista só por admins e por quem recebe (RN26).
- **Escuro por padrão, claro como alternativa.** Os dois servem para jogo em qualquer horário e têm a mesma estrutura.

## Cores

### Base escura (padrão)

As camadas se separam por luminosidade: fundo, superfície e superfície 2. Cards não têm sombra, e é o degrau de cor que separa os planos.

| Token | Hex | Uso |
| --- | --- | --- |
| `background` | `#0F1833` | Fundo das telas |
| `surface` | `#192853` | Cards, campos, navegação, sheets |
| `surfaceHigh` | `#2A3A68` | Divisores, card sobre card, botão de ícone, desabilitado, contorno |
| `onSurface` | `#ECF4F7` | Texto principal (14,9:1 no fundo) |
| `onSurfaceVariant` | `#A9B6D3` | Texto secundário, legendas (8,9:1 no fundo) |
| `primary` | `#FFE14F` | Ação: CTA, item ativo, foco. Texto em cima `#192853` |
| `primaryPressed` | `#E6C835` | CTA pressionado |
| `destructive` | `#D93A2B` | Só na confirmação final, com texto branco (4,6:1) |
| `errorText` | `#FF9B90` | Erro, vencida, ação destrutiva secundária |

### Base clara

| Token | Hex |
| --- | --- |
| `background` | `#ECF4F7` |
| `surface` | `#FFFFFF` |
| `line` | `#D3E0E8` |
| `onSurface` | `#192853` |
| `onSurfaceVariant` | `#5A6B8C` |
| ícone neutro | `#EEF2F5` |
| desabilitado | `#E3EAF0` |

**Não mudam no claro:** os blocos de significado, a navegação inferior (navy `#192853`) e o amarelo de ação.

**Mudam no claro:**
- links e texto de ação deixam de ser amarelos e viram navy sublinhado;
- foco de campo com borda navy;
- lilás usado como texto vira `#4B3A99`;
- erro vira `#B3261E`.

### Blocos por significado

São cinco cores claras e saturadas, iguais nos dois modos, para os blocos grandes. Todas levam texto `#192853`, com contraste entre 6,5:1 e 10,8:1. **Nunca texto branco sobre amarelo.**

| Significado | Token | Hex | Uso |
| --- | --- | --- | --- |
| Jogo / ação | `jogo` | `#FFE14F` | Jogo aberto ou confirmado, CTA, item ativo da navegação, convite, vaga liberada |
| Você deve | `deve` | `#FF8F6B` | Aba "A pagar", topo da cobrança a pagar, aviso de vencida |
| Você recebe | `recebe` | `#7CDCC8` | Aba "A receber", pago, comprovante enviado, perfil |
| Espera | `espera` | `#B8A6FF` | Lista de espera, jogo lotado |
| Rateio | `rateio` | `#8EC5FF` | Valor por vaga antes de liberar, locais, informação |

**Regra de densidade:** no máximo **um bloco grande** por tela, que é o topo ou o herói, e **dois pequenos**.

### Selos de status

O selo é uma pílula de 24 px com um ponto de 7 px e o texto. O texto sempre aparece.

| Tom | Escuro (fundo / texto) | Claro (fundo / texto) | Ponto |
| --- | --- | --- | --- |
| `ok` | `rgba(46,204,113,.18)` / `#7BE3A6` | `#E3F8EC` / `#136B3D` | `#2ECC71` |
| `warn` | `rgba(255,159,67,.18)` / `#FFC48A` | `#FFF0E1` / `#8F4A00` | `#FF9F43` |
| `bad` | `rgba(231,76,60,.22)` / `#FF9B90` | `#FCE6E3` / `#B3261E` | `#E74C3C` |
| `info` | `#2A3A68` / `#ECF4F7` | `#DCE6F5` / `#192853` | `#8EC5FF` |
| `wait` | `rgba(184,166,255,.2)` / `#D3C9FF` | `#EEEAFF` / `#4B3A99` | `#B8A6FF` |
| `neu` | `#2A3A68` / `#A9B6D3` | `#EEF2F5` / `#5A6B8C` | `#A9B6D3` |

### Cor do grupo

`grupo.cor` tem seis opções, escolhidas no formulário de grupo:

| Nome | Hex |
| --- | --- |
| Azul | `#3B6FE0` |
| Turquesa | `#0FA3A0` |
| Roxo | `#7B5CE6` |
| Rosa | `#E0559B` |
| Lima | `#7FB22A` |
| Grafite | `#5A6B8C` |

A cor do grupo aparece **só** como ponto no selo de origem e no ícone do grupo. O ícone é um quadrado arredondado, de raio igual ao lado dividido por 3,4, com as iniciais em Montserrat 800 brancas. Nunca vira bloco grande, para não competir com as cores de significado.

## Mapa de status

Cada valor de enum vira um selo, de acordo com a tabela abaixo. Os nomes de enum são os de `supabase/migrations/…_enums.sql`.

**Participação (`participacao_status`)**

| Valor | Selo |
| --- | --- |
| `confirmado` | `ok` "Confirmado" |
| `lista_espera` | `wait` "2º na espera" (com a posição) |
| `cancelou_no_prazo` | `neu` "Cancelou" |
| `cancelou_fora_do_prazo` | `bad` "Cancelou tarde" |
| `faltou` | `bad` "Faltou" |

**Cobrança (`cobranca_status`)**

| Valor | Momento | Selo |
| --- | --- | --- |
| `pendente` | antes do encerramento do jogo | `neu` + cadeado (`lock`) "Libera após o jogo" |
| `pendente` | liberada | `warn` "A pagar" |
| `pendente` | vencida | `bad` "Vencida" |
| `comprovante_enviado` | visto pelo devedor | `info` + ampulheta (`hourglass_top`) "Em análise" |
| `comprovante_enviado` | visto pelo credor | `info` + recibo (`receipt_long`) "Conferir" |
| `confirmado` | — | `ok` "Pago" |
| `isenta` | — | `neu` "Isenta" |
| `cancelada` | — | `neu` "Cancelada", com texto riscado |

**Comprovante (`comprovante_resultado`)**

| Valor | Selo |
| --- | --- |
| `consistente` | `ok` + `check` "Confere" |
| `divergente` | `warn` + `warning` "Divergente" |
| `ilegivel` | `neu` + `help` "Ilegível" |

**Jogo (`jogo_status`)**

| Valor | Selo |
| --- | --- |
| `aberto` | pílula amarela `#FFE14F`, texto navy, "Aberto" |
| `encerrado` | pílula `#ECF4F7`, texto navy, "Encerrado" |
| `cancelado` | `bad` "Cancelado" |

**Marca de débito vencido (RN26).** É um círculo de 18 px, fundo `rgba(231,76,60,.22)`, com o ícone `priority_high` em `#FF9B90`, ao lado do nome. Só admins e quem recebe a veem, conforme a `listar_participantes`.

## Tipografia

Três famílias, cada uma com um papel:
- **Montserrat 700–800**: títulos de tela, nomes de jogo e de grupo, títulos de seção, iniciais de avatar. Sempre em caixa normal.
- **Bebas Neue**: **só números**: valores, horários, vagas, posição na espera, código de seis dígitos. Nunca em frase. Letter-spacing +0,3.
- **Roboto 400 / 500 / 700**: texto, listas, campos e botões. É a fonte nativa do Android.

| Token | Fonte | Peso / tamanho / altura | Uso |
| --- | --- | --- | --- |
| `number.hero` | Bebas Neue | 84 | Valor no topo da cobrança |
| `number.xl` | Bebas Neue | 52–64 | Horário no topo do jogo |
| `number.lg` | Bebas Neue | 34–50 | Valores dos blocos |
| `number.md` | Bebas Neue | 22–28 | Stats, valor em lista |
| `title.xl` | Montserrat | 800 / 28 | Título de tela-raiz |
| `title.lg` | Montserrat | 800 / 22–24 | Título de sheet, nome do grupo |
| `title.md` | Montserrat | 700 / 15–18 | Seção, nome |
| `body.lg` | Roboto | 400 / 16 / 24 | Texto corrido |
| `body.md` | Roboto | 400 / 14 / 20 | Texto de lista e aviso |
| `label` | Roboto | 700 / 16 | Botões |
| `caption` | Roboto | 400 / 12 / 16 | Legendas, prazos |

## Forma, espaço e ícones

**Raios**

| Elemento | Raio |
| --- | --- |
| Bloco, sheet | 28 (sheet só nos cantos de cima) |
| Topo de tela | 32, só nos cantos de baixo |
| Card | 22 |
| Stat | 20 |
| Campo, contador, seletor | 16 |
| Quadrado de ícone | 12–16 (14 em listas e avisos) |
| Botão, selo | 999 (pílula) |

As formas são cheias e generosas, sem canto vivo.

**Espaçamento:** 4 (xs, entre ícone e texto) · 8 (sm, dentro de selo e entre chips) · 16 (md, margem lateral e padding de card) · 24 (lg, entre blocos) · 32 (xl, topo de estado vazio).
- Margem lateral de 16, ou de 24 nas telas de formulário e de acesso.
- Entre cards de uma mesma lista, 12.
- Alvo de toque mínimo de 44 px.

**Sombra:** cards não têm. Só o FAB (`0 6 18 rgba(0,0,0,.45)`) e o menu popup (`0 12 32 rgba(0,0,0,.5)`) levam sombra.

**Decoração:** blocos coloridos e topos levam um círculo vazado, com borda de 18 a 30 px em `rgba(25,40,83,.08)` e parte do raio fora do bloco.

**Ícones:** Material Symbols Rounded, pelo pacote `material_symbols_icons`, peso 400, 24 px. O preenchido (`FILL 1`) aparece só no item ativo da navegação. Em listas e avisos, o ícone vai num quadrado de raio 14 na cor do assunto.

## Componentes

### Botões

Todos são pílulas de altura 56, com texto Roboto 700 16 e ícone opcional de 22.

| Variante | Escuro | Claro |
| --- | --- | --- |
| Primário | Fundo `#FFE14F`, texto `#192853`. **Um por tela** | Igual |
| Secundário | Fundo `#ECF4F7`, texto navy | Fundo navy, texto `#ECF4F7` |
| Contorno | Borda 1,5 px `#2A3A68`, texto padrão | Borda navy |
| Destrutivo sólido | Fundo `#D93A2B`, texto branco. Só na confirmação final | Igual |
| Destrutivo contorno | Borda `#2A3A68`, texto `#FF9B90` | Texto `#B3261E` |
| Texto | Sem fundo | Navy sublinhado |
| Desabilitado | Fundo `#2A3A68`, texto `#A9B6D3` | Fundo `#E3EAF0` |

### Campo

- Altura 56, raio 16, fundo `surface`, borda 1,5 px `#2A3A68`.
- O rótulo fica **acima do campo, fora dele**, em 13 px 500 `#A9B6D3`.
- Foco: borda 2 px `#FFE14F` (navy no claro).
- Erro: borda 2 px `#FF9B90`, ícone `error` e mensagem de 12 px. Erro nunca é indicado só pela cor.
- Dinheiro: prefixo "R$" e valor em Bebas 26. Uma dica opcional abaixo do campo, como "Sugerido: 2 h × R$ 150,00.".

### Contador (stepper)

Altura 56, raio 16. O botão − é um círculo de 40 em `#2A3A68`; o botão + é um círculo de 40 amarelo, por ser a ação mais comum. O valor fica no centro, em Bebas 28.

### Seletor de opção

Duas ou três células de altura 56 e raio 16. A selecionada tem borda 2 px amarela, fundo `#2A3A68` e texto 700. Interruptores, como "Avisos por push", usam o check amarelo.

### Filtros (chips)

O ativo tem fundo Alice Blue `#ECF4F7` e texto navy. O inativo tem só contorno.

### Navegação inferior

- Altura 76, fundo `#192853`, cantos de cima 28. É navy também no claro.
- Quatro destinos: **Jogos** (`sports_volleyball`), **Grupos** (`groups`), **Cobranças** (`payments`) e **Perfil** (`person`).
- Item ativo: círculo de 56 amarelo, ícone `FILL 1`, anel de 5 px na cor do fundo, elevado 26 px; rótulo amarelo 700.
- Inativos: ícone e rótulo em `#A9B6D3`.
- Selo vermelho `#E74C3C` com número em Cobranças, para débitos a pagar.
- A navegação troca de raiz sem empilhar.

### Barra superior

- **Raiz:** título Montserrat 800 28, subtítulo opcional de 14, e à direita um botão circular de 44 com o sino. O sino abre os avisos (G1) e leva um ponto amarelo de 10 px com anel navy quando há aviso não lido. Na raiz Jogos há também o "+" amarelo para criar jogo.
- **Interna:** botão circular de voltar e título Montserrat 700 18.

### Topo colorido (herói de jogo ou cobrança)

Bloco com cantos de baixo 32 e botões circulares navy sobre ele. Contém a pílula do grupo, a data (14, 700), o horário em Bebas 52 e o local. A cor segue o significado: amarelo para jogo, lilás para lotado, coral para cobrança. O anel segmentado mostra as vagas, com um gomo por vaga.

### Blocos de valor

São os atalhos do feed para Cobranças: "A pagar" em coral e "A receber" em menta, cada um com o valor em Bebas e uma linha de apoio ("1 vencida", "4 pessoas").

### Trio de números (stats)

Três cards de raio 20, cada um com rótulo de 12 e número em Bebas 26, logo abaixo do topo do jogo. Um dos três pode receber cor de significado, como o céu no valor do rateio.

### Anéis e barras

- Segmentado para o que se conta, como as vagas: um gomo por vaga, com cortes de 2,5°.
- Contínuo para proporção, como o percentual recebido.
- Barra de ocupação de 6 px: amarela para vagas, lilás quando o jogo está lotado com espera, menta para o recebido.

### Card de jogo

- À esquerda, um bloco de data de 58 px em `#2A3A68`: dia da semana em Bebas 13 `#A9B6D3`, dia em 30, hora em 16 amarela.
- Ao lado: grupo (ponto e nome em 12), local em Montserrat 700 15, vagas em Bebas 19 com o selo.
- Embaixo, a barra de ocupação.

### Linha de pessoa ou de cobrança

Avatar de 44, nome 15 700, subtítulo de 12. À direita, o valor em Bebas 22 com o selo embaixo. Altura mínima de 64, com divisor recuado 70 px.

### Avatar

- Círculo com iniciais em Montserrat 800 e texto navy, sobre um dos pastéis `#FFB4A2`, `#9FD8F5`, `#C9B8FF`, `#9EE6CF`, `#FFD27A` e `#F7A8D0`.
- "Você" sempre em `#FFE14F`. Na lista de quem vai, com anel amarelo de 3 px.
- Pilha de avatares com "+N" e o resumo ao lado ("Ana, Bruno e mais 10").

### Aviso inline

Card `surface` com um quadrado de ícone de 40, raio 13, na cor do assunto. Texto 14/20 em cor clara.

### Sheet

Fundo `surface`, cantos de cima 28, alça de 36×4. O véu é `rgba(5,10,25,.72)` no escuro e `rgba(15,24,51,.55)` no claro.

### Lista de avisos

Cada item tem o quadrado de ícone na cor do assunto. Os não lidos ficam em card `surface`, com ponto amarelo.

### Logo

Ainda não existe. Até o passo 10, usa-se um espaço reservado tracejado com o texto `LOGO`.

## Escrita e formatos

**Tom.** Segunda pessoa, frase curta e concreta, como já está no código ("Como a turma vai te ver?"). Um pouco de calor nas saudações ("Oi, Thiago"), nunca em dinheiro.

**Botões dizem o verbo:** "Confirmar presença", "Enviar comprovante", "Dar baixa". Antes de uma ação com custo, a tela diz o custo em reais (B4).

| Formato | Exemplo |
| --- | --- |
| Dinheiro | `R$ 14,29` (sempre com centavos; armazenado em centavos) |
| Data curta | `qui, 23 out` |
| Hora | `19:30`, horário de Brasília |
| Duração | `2 h` · `1 h 30` |
| Vagas | `12/14` |
| Espera | `2º na espera` |

## Telas

Os estados e os textos exatos estão nas imagens de `telas/`, sob o mesmo id. A coluna PNG indica os grupos que já têm imagem.

| Grupo | Telas | PNG | Arquivos atuais |
| --- | --- | --- | --- |
| **A · Acesso** | A1 Entrar (e-mail, senha, Google, "Esqueci a senha", topo amarelo com logo) · A2 Criar conta (nome obrigatório) · A3 Confirmar e-mail (seis casas, reenvio com contagem) · A4 Redefinir senha (RF41) | `telas/acesso/`: `a1-acesso.png`, `a2-criar_conta.png`, `a3-confirma_email.png`, `a4-redefinir_senha.png` | `entrar_tela.dart`, `etapa_codigo.dart` |
| **B · Jogos e presença** | B1 Feed (herói do próximo jogo, blocos A pagar e A receber, lista da semana, filtro por grupo) · B2 Jogo antes de confirmar · B3 Jogo confirmado (cancelar, convidar) · B4 Sheet de cancelamento fora do prazo, com o custo em reais (RN02, RN03, RN05) · B5 Lista de espera (posição, sem cobrança) · B6 Vaga liberada (RF17, RN08) · B7 Marcar faltas (RF18, RN04) | — | `inicio_tela.dart` |
| **C · Criar, editar e duplicar jogo** | C1 grupo, local, quadra, data, início, duração · C2 vagas, custo, valor por vaga ao vivo (arredonda para cima, mostra a sobra), prazo sem multa, quem recebe · C3 jogo avulso com chave Pix faltando (erro) · C4 editar (avisa N confirmados) · C5 duplicar (só data e horário) | — | — |
| **D · Grupos e convites** | D1 lista · D2 grupo (regras, próximos jogos) · D3 membros (menu promover e remover, marca de débito só para admin) · D4 novo grupo · D5 editar regras · D6 convite (link multiuso, revogar) · D7 abrir convite · D8 convite revogado · D9 convite de jogo | — | — |
| **E · Locais** | E1 busca e lista por proximidade · E2 detalhes (quadras, horários) | — | — |
| **F · Cobranças** | F1 a pagar (pagar agora, aguardando o jogo, resolvidas) · F2 pagar (valor grande, chave Pix copiável, rateio) · F3 enviar comprovante (campos lidos no aparelho) · F4 comprovante já usado (RN10) · F5 enviado · F6 a receber · F7 revisar comprovante (triagem automática, dar baixa ou isentar, só após o encerramento) | — | — |
| **G · Avisos** | G1 lista. O sino é a fonte de verdade; o push só entrega | — | — |
| **H · Perfil e conta** | H1 perfil, com a linha "Aparência" (Escuro ou Claro), que não está no desenho · H2 editar (nome, telefone, chave Pix) · H3 trocar e-mail · H4 excluir conta bloqueada por cobranças em aberto (RN27) | — | `trocar_email_tela.dart` |
| **X · Modo claro** | X1–X3 e 12 telas-chave no tema claro | — | — |

## Comportamento que o design pressupõe

São regras do PRD que as telas tornam visíveis, listadas aqui para quem implementa a tela. A fonte continua sendo o PRD.

- Confirmar presença cria a cobrança congelada (RN07), que só libera após o encerramento do jogo.
- Cancelar fora do prazo mantém a cobrança, a menos que alguém da espera pegue a vaga (RN03, RN05). O valor em reais aparece antes do toque.
- Vaga liberada: todos da espera são avisados juntos, e a vaga fica com quem confirmar primeiro (RN08).
- Comprovante: o app lê os campos no aparelho e envia; o servidor classifica (RN09). A triagem não prova o crédito; só o credor dá baixa.
- Valor por vaga = custo ÷ vagas, arredondado para cima no centavo (RN16).
- Datas e horas em horário de Brasília.

## Tema Flutter

O tema mora em `app/lib/core/tema.dart`.

```dart
ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFE14F), onPrimary: Color(0xFF192853),
  secondary: Color(0xFFECF4F7), onSecondary: Color(0xFF192853),
  surface: Color(0xFF192853), surfaceContainerHigh: Color(0xFF2A3A68),
  onSurface: Color(0xFFECF4F7), onSurfaceVariant: Color(0xFFA9B6D3),
  outline: Color(0xFF2A3A68),
  error: Color(0xFFFF9B90), onError: Color(0xFF192853),
)
scaffoldBackgroundColor: Color(0xFF0F1833)
```

- **`ThemeExtension` `VoleiCores`**:
  - `jogo 0xFFFFE14F`, `deve 0xFFFF8F6B`, `recebe 0xFF7CDCC8`, `espera 0xFFB8A6FF` e `rateio 0xFF8EC5FF`, iguais nos dois modos;
  - os pares fundo e texto dos selos, com versão clara.
- **Tema claro:** os mesmos nomes, com os valores da base clara.
- **Modo:** escuro, a menos que a pessoa escolha o claro no perfil. A escolha fica guardada no aparelho com `shared_preferences`.
- **Fontes:** `fontFamily` de Montserrat e Bebas Neue pelos assets de `app/assets/fonts/`; Roboto é a do sistema.
- As telas leem cor e texto do tema (`Theme.of`, `VoleiCores`), nunca de um hex solto no widget.

## Fora do design

- **Estados de carregamento e vazio** não foram desenhados nesta rodada. Seguem o padrão do herói, com bloco colorido e texto curto.
- **Gamificação** (reputação, conquistas, ranking) está fora do MVP e não foi desenhada. O sistema de cores foi pensado para recebê-la depois.
- **Imagens e ilustrações:** não há. O espaço da imagem do comprovante aparece como placeholder listrado.

## Decisões de implementação · 2026-10-21

O handoff deixava quatro pontos em aberto. Nenhum deles era respondido pela referência visual, que pressupunha fontes e ícones vindos do CDN do Google, recurso que só existe no navegador, nem pelo PRD. Foram fechados assim:

- **Fontes em assets locais.** Os `.ttf` de Montserrat (700 e 800) e Bebas Neue ficam em `app/assets/fonts/`, declarados no `pubspec.yaml`. O motivo é funcionar offline desde a primeira abertura, sem pacote novo. Roboto é a fonte do sistema e não entra como asset. O `google_fonts` fica fora.
- **Ícones pelo pacote `material_symbols_icons`.** Ele é gratuito e traz Material Symbols Rounded com o eixo de preenchimento, o que dá o `FILL 1` do item ativo da navegação igual ao design. Os `Icons.*` nativos não são usados nas telas novas.
- **Modo escuro fixo por padrão, com opção no perfil.** O H1 ganha uma linha "Aparência", com Escuro e Claro, que o design não desenhou. A escolha fica guardada no aparelho, não em `pessoa`, num pacote de armazenamento local (`shared_preferences`). Sem escolha feita, o app abre escuro. O modo não segue o do sistema.
- **Logo:** o espaço reservado `LOGO` fica até o passo 10. Até lá só as contas de desenvolvimento usam o app, e o logo entra antes de o APK chegar à turma.

Os dois pacotes novos (`material_symbols_icons` e `shared_preferences`) precisam entrar na lista de pacotes de `docs/stack.md`, e os assets de fonte na estrutura de pastas.
