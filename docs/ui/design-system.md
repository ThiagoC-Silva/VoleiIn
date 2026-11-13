# Design System

> Decisões de 09/11/2026. Base: `requisitos-nao-funcionais.md` (RNF05, RNF06), `modelo-dados.md` (enums) e o visual do projeto anterior (VoleiIn v0), do qual vieram as cores, as fontes e os componentes. As telas do v0 não foram trazidas: cada tela é descrita em `docs/ui/telas.md`, fatia a fatia.
> Este documento decide **aparência**. Não decide regra, texto final nem quais telas existem. Regra vem de `regras-negocio.md`; texto, do catálogo de textos (`plan-docs.md`, seção 4.3); telas, de `docs/ui/telas.md`.

## 1. Como usar

Para montar uma tela:

1. Leia a descrição da tela em `docs/ui/telas.md`.
2. Use só os tokens (seções 3 a 6) e os componentes (seção 7) daqui. Componente novo entra neste documento antes de entrar no código.
3. No código, cor e estilo de texto vêm de `Theme.of(context)` e de `VoleiColors.of(context)` (seção 9). Nunca de um hex solto no widget.
4. Confira a lista de acessibilidade (seção 8).

## 2. Princípios

- **Só modo escuro.** O app tem uma base de cores, escura. Não há modo claro nem opção de aparência, e o app não segue o tema do sistema.
- **A cor diz o que é.** Amarelo é jogo e ação, coral é o que você deve, menta é o que você recebe, lilás é espera e lotação, céu é rateio e informação. A mesma cor significa a mesma coisa em todas as telas.
- **Número grande, frase curta.** Valores, horários e vagas aparecem em Bebas Neue, grandes o bastante para ler de relance na quadra. O texto ao lado explica em uma linha.
- **Dinheiro sem ambiguidade.** Sempre `R$` com centavos, sempre com quem recebe. Status de valor sempre com texto, nunca só com cor (RNF05).
- **Formas cheias.** Cantos generosos, sem canto vivo, e sem sombra em card: é o degrau de cor que separa os planos.

## 3. Cores

### 3.1 Base

As camadas se separam por luminosidade: fundo, superfície e superfície alta.

| Token | Hex | Uso |
|-------|-----|-----|
| `background` | `#0F1833` | Fundo das telas |
| `surface` | `#192853` | Cards, campos, navegação, sheets |
| `surfaceHigh` | `#2A3A68` | Divisores, card sobre card, botão de ícone, desabilitado, contorno |
| `onSurface` | `#ECF4F7` | Texto principal (14,9:1 sobre o fundo) |
| `onSurfaceVariant` | `#A9B6D3` | Texto secundário, legendas (8,9:1 sobre o fundo) |
| `primary` | `#FFE14F` | Ação: botão principal, item ativo, foco. Texto em cima: `#192853` |
| `primaryPressed` | `#E6C835` | Botão principal pressionado |
| `destructive` | `#D93A2B` | Só no botão da confirmação final de uma ação destrutiva, com texto branco (4,6:1) |
| `errorText` | `#FF9B90` | Mensagem de erro, ação destrutiva secundária |

### 3.2 Blocos por significado

Cinco cores claras e saturadas para os blocos grandes (topo de tela, herói, atalhos). Todas levam texto `#192853`, com contraste entre 6,5:1 e 10,8:1. **Nunca texto branco sobre elas.**

| Significado | Token | Hex | Uso |
|-------------|-------|-----|-----|
| Jogo e ação | `game` | `#FFE14F` | Jogo Aberto, botão principal, item ativo, convite, vaga liberada |
| Você deve | `owe` | `#FF8F6B` | Total a pagar, topo de um valor a pagar, multa |
| Você recebe | `receive` | `#7CDCC8` | Total a receber, valor Pago, comprovante Aprovado |
| Espera e lotação | `wait` | `#B8A6FF` | Lista de espera, jogo Confirmado (lista cheia) |
| Rateio e informação | `split` | `#8EC5FF` | Estimativa por pessoa (RN24), parte por vaga, rateio do jogo, avisos informativos |

**Densidade:** no máximo **um bloco grande** por tela (o topo ou o herói) e **dois pequenos**.

### 3.3 Selos de status

O selo é uma pílula com um ponto e o texto. O texto sempre aparece.

| Tom | Fundo | Texto | Ponto |
|-----|-------|-------|-------|
| `ok` | `rgba(46,204,113,.18)` | `#7BE3A6` | `#2ECC71` |
| `warn` | `rgba(255,159,67,.18)` | `#FFC48A` | `#FF9F43` |
| `bad` | `rgba(231,76,60,.22)` | `#FF9B90` | `#E74C3C` |
| `info` | `#2A3A68` | `#ECF4F7` | `#8EC5FF` |
| `waiting` | `rgba(184,166,255,.2)` | `#D3C9FF` | `#B8A6FF` |
| `neutral` | `#2A3A68` | `#A9B6D3` | `#A9B6D3` |

### 3.4 Avatar

- Sem foto: círculo com as iniciais em Montserrat 800, texto `#192853`, sobre um dos pastéis `#FFB4A2`, `#9FD8F5`, `#C9B8FF`, `#9EE6CF`, `#FFD27A` e `#F7A8D0`. O pastel é escolhido pelo `id` do perfil (resto da divisão do hash por 6), para a mesma pessoa ter sempre a mesma cor.
- "Você" usa sempre `#FFE14F`.
- Perfil anonimizado (RN104): ícone de pessoa em `#A9B6D3` sobre `#2A3A68`, sem iniciais.
- O grupo segue a mesma regra: foto ou iniciais sobre pastel, num quadrado de cantos arredondados (raio = lado ÷ 3,4).

## 4. Mapa de status

Cada valor de enum vira um selo ou uma pílula. Os rótulos são os da seção 3 do `modelo-dados.md`. Textos compostos, como "Cancelou fora do prazo" e "2º na espera", ficam no catálogo de textos. Aqui só se define o tom.

**Jogo (`game_status`)**

| Valor | Aparência |
|-------|-----------|
| `open` | Pílula `game` (amarela), texto navy, "Aberto" |
| `confirmed` | Pílula `wait` (lilás), texto navy, "Confirmado" |
| `completed` | Pílula `#ECF4F7`, texto navy, "Concluído" |
| `cancelled` | Selo `bad`, "Cancelado" |

Jogo em andamento (derivado: `starts_at <= now()` e não concluído) mantém a pílula do status e ganha o selo `info` "Em andamento". O "agora" vem do servidor (RN02).

**Valor a pagar (`charge_status`)**

| Valor | Selo |
|-------|------|
| `pending` | `warn` "Pendente" |
| `under_review` | `info`, com ícone `hourglass_top`, "Em análise" |
| `paid` | `ok` "Pago" |
| `waived` | `neutral` "Isento" |

**Comprovante (`receipt_status`)**

| Valor | Selo |
|-------|------|
| `under_review` | `info`, com ícone `hourglass_top`, "Em análise" |
| `approved` | `ok`, com ícone `check`, "Aprovado" |
| `rejected` | `bad`, com ícone `close`, "Recusado" |

**Passagem pela lista (`participant_status`)**

| Valor | Selo |
|-------|------|
| `active` | `ok` "Na lista" |
| `left_after_start` | `bad` "Saiu após o início" |
| `cancelled` com `late_cancellation = false` | `neutral` "Cancelou" |
| `cancelled` com `late_cancellation = true` | `bad`, com o texto do catálogo |
| `removed` | `neutral` "Removido" |
| Falta (`absent = true`) | `bad`, com o texto do catálogo |
| Posição na espera | `waiting`, com a posição |

**Papéis:** admin do grupo, admin do jogo e recebedor aparecem como selo `neutral` ao lado do nome.

## 5. Tipografia

Três famílias, cada uma com um papel:

- **Montserrat 700 e 800:** títulos de tela, nomes de jogo e de grupo, títulos de seção, iniciais de avatar. Sempre em caixa normal.
- **Bebas Neue:** **só números** (valores, horários, vagas, posição na espera). Nunca em frase. Espaçamento entre letras +0,3.
- **Roboto 400, 500 e 700:** texto, listas, campos e botões. É a fonte do sistema Android.

| Token | Fonte | Peso / tamanho / altura | Uso |
|-------|-------|-------------------------|-----|
| `number.hero` | Bebas Neue | 84 | Valor no topo de um valor a pagar |
| `number.xl` | Bebas Neue | 56 | Horário no topo do jogo |
| `number.lg` | Bebas Neue | 40 | Valores dos blocos |
| `number.md` | Bebas Neue | 26 | Números em card, valor em lista |
| `title.xl` | Montserrat | 800 / 28 | Título de tela-raiz |
| `title.lg` | Montserrat | 800 / 22 | Título de sheet, nome do grupo |
| `title.md` | Montserrat | 700 / 18 | Título de tela interna |
| `title.sm` | Montserrat | 700 / 15 | Seção, nome em lista |
| `body.lg` | Roboto | 400 / 16 / 24 | Texto corrido |
| `body.md` | Roboto | 400 / 14 / 20 | Texto de lista e aviso |
| `label` | Roboto | 700 / 16 | Botões |
| `caption` | Roboto | 400 / 12 / 16 | Legendas, prazos |

Os tamanhos são a base. Todos crescem com a fonte do sistema até 150% (seção 8).

## 6. Forma, espaço e ícones

**Raios**

| Elemento | Raio |
|----------|------|
| Bloco, sheet | 28 (sheet só nos cantos de cima) |
| Topo colorido de tela | 32, só nos cantos de baixo |
| Card | 22 |
| Card de número | 20 |
| Campo, contador, seletor | 16 |
| Quadrado de ícone | 14 |
| Botão, selo | Pílula |

**Espaçamento:** 4 (entre ícone e texto) · 8 (dentro de selo, entre chips) · 12 (entre cards de uma lista) · 16 (margem lateral, padding de card) · 24 (entre blocos; margem lateral de formulários) · 32 (topo de estado vazio).

**Sombra:** card não tem. Só o botão flutuante (`0 6 18 rgba(0,0,0,.45)`) e o menu suspenso (`0 12 32 rgba(0,0,0,.5)`).

**Decoração:** blocos coloridos e topos podem levar um círculo vazado, com borda de 18 a 30 em `rgba(25,40,83,.08)`, parcialmente fora do bloco.

**Ícones:** Material Symbols Rounded, pelo pacote `material_symbols_icons`, peso 400, 24. O preenchido aparece só no item ativo da navegação. Os `Icons.*` do Material não são usados.

## 7. Componentes

Todo componente tem altura **mínima**, não fixa, para crescer com a fonte do sistema.

### 7.1 Botões

Pílulas de altura mínima 56, texto `label`, ícone opcional de 22.

| Variante | Aparência | Regra |
|----------|-----------|-------|
| Principal | Fundo `primary`, texto `#192853` | **Um por tela** |
| Secundário | Fundo `#ECF4F7`, texto `#192853` | |
| Contorno | Borda 1,5 `surfaceHigh`, texto `onSurface` | |
| Destrutivo sólido | Fundo `destructive`, texto branco | Só no botão final de uma confirmação destrutiva |
| Destrutivo contorno | Borda `surfaceHigh`, texto `errorText` | Ação destrutiva que ainda pede confirmação |
| Texto | Sem fundo, texto `primary` | Ações secundárias, links |
| Desabilitado | Fundo `surfaceHigh`, texto `onSurfaceVariant` | |
| Carregando | Mantém a variante e troca o texto por um indicador de progresso | Bloqueia novo toque |

### 7.2 Campo de texto

- Altura mínima 56, raio 16, fundo `surface`, borda 1,5 `surfaceHigh`.
- Rótulo **acima do campo**, fora dele, em 13 / 500 `onSurfaceVariant`.
- Foco: borda 2 `primary`.
- Erro: borda 2 `errorText`, ícone `error` e mensagem de 12 abaixo. O erro nunca é indicado só pela cor.
- Dinheiro: prefixo `R$` e valor em Bebas Neue 26. O valor digitado vira centavos inteiros (RN04).
- Data e hora: abre o seletor nativo e mostra o valor em `dd/mm/aaaa` e `HH:mm`, em `America/Fortaleza` (RNF06).

### 7.3 Contador (vagas)

Altura mínima 56, raio 16. O botão − é um círculo de 48 em `surfaceHigh`. O botão + é um círculo de 48 em `primary`, por ser a ação mais comum. O valor fica no centro, em Bebas Neue 28.

### 7.4 Seletor de opção

Duas ou três células de altura mínima 56 e raio 16. A selecionada tem borda 2 `primary`, fundo `surfaceHigh` e texto 700. Interruptores (preferências de notificação) usam o `Switch` do tema, com trilho `primary` quando ligado.

### 7.5 Chips de filtro

O ativo tem fundo `#ECF4F7` e texto `#192853`. O inativo tem só contorno `surfaceHigh`.

### 7.6 Navegação inferior

- Altura mínima 76, fundo `surface`, cantos de cima 28.
- Até quatro destinos de raiz. Quais são está em `docs/ui/telas.md`.
- Item ativo: círculo de 56 em `primary`, ícone preenchido, anel de 5 na cor do fundo, elevado; rótulo `primary` 700.
- Inativos: ícone e rótulo em `onSurfaceVariant`.
- Contador em vermelho `#E74C3C`, com número, quando há algo a pagar.
- A navegação troca de raiz sem empilhar.

### 7.7 Barra superior

- **Raiz:** título `title.xl`, subtítulo opcional de 14 e, à direita, o botão circular de 48 do sino. O sino leva um ponto `primary` de 10, com anel na cor do fundo, quando há notificação não lida.
- **Interna:** botão circular de voltar e título `title.md`.

### 7.8 Topo colorido (herói de jogo ou de valor a pagar)

Bloco com cantos de baixo 32 e botões circulares navy sobre ele. Contém a pílula do grupo (ou "Avulso"), a data (14 / 700), o horário em `number.xl` e o local. A cor segue o significado: `game` para jogo Aberto, `wait` para Confirmado, `owe` para valor a pagar. O anel segmentado mostra as vagas, com um gomo por vaga.

### 7.9 Blocos de valor

Atalhos para os totais: "a pagar" em `owe` e "a receber" em `receive`, cada um com o valor em Bebas Neue e uma linha de apoio (por exemplo, o número de jogos).

### 7.10 Trio de números

Três cards de raio 20, cada um com rótulo de 12 e número em `number.md`, logo abaixo do topo do jogo (por exemplo: vagas, estimativa por pessoa e prazo). Um dos três pode receber cor de significado, como `split` na estimativa.

### 7.11 Anéis e barras

- Anel segmentado para o que se conta (vagas): um gomo por vaga.
- Anel contínuo para proporção (percentual recebido).
- Barra de ocupação de 6: `game` para vagas, `wait` quando a lista está cheia, `receive` para o recebido.

### 7.12 Card de jogo

- À esquerda, um bloco de data de 58 de largura em `surfaceHigh`: dia da semana em Bebas Neue 13 `onSurfaceVariant`, dia em 30, hora em 16 `primary`.
- Ao lado: grupo (nome em 12, ou "Avulso"), local em `title.sm`, vagas em Bebas Neue 19 e a pílula de status.
- Embaixo, a barra de ocupação.

### 7.13 Linha de pessoa ou de valor

Avatar de 44, nome `title.sm`, subtítulo de 12. À direita, o valor em Bebas Neue 22 com o selo embaixo. Altura mínima de 64, com divisor recuado 70.

### 7.14 Aviso em linha

Card `surface` com um quadrado de ícone de 40, raio 14, na cor do assunto, e texto `body.md`. Para bloqueios explicados (por exemplo, "indique outro recebedor antes de sair").

### 7.15 Sheet e diálogo de confirmação

- Sheet: fundo `surface`, cantos de cima 28, alça de 36 × 4, véu `rgba(5,10,25,.72)`.
- Confirmação destrutiva (sair do grupo, cancelar jogo, excluir conta): sheet com título, uma frase sobre a consequência, o botão destrutivo sólido e o botão de contorno "voltar". Se a ação tem custo em reais, o valor aparece antes do botão.

### 7.16 Estados de tela

Toda tela tem os quatro estados abaixo, além do conteúdo.

| Estado | Aparência |
|--------|-----------|
| Carregando | Indicador de progresso circular em `primary`, centralizado. Listas mostram o indicador no lugar da lista, nunca uma tela branca |
| Vazio | Ícone de 48 em `onSurfaceVariant` num quadrado de raio 14, título `title.sm`, uma frase `body.md` e, se houver, o botão da ação que resolve (por exemplo, "Criar jogo"). Topo a 32 |
| Erro | Mesmo formato do vazio, com o ícone `error_outline`, o texto do código de erro (catálogo de textos) e o botão "Tentar de novo" |
| Sem conexão | Mesmo formato, com o ícone `wifi_off` e "Tentar de novo" (RNF07) |
| Sem permissão | Tratado como "não encontrado" (`contratos-api.md`, seção 1: sem acesso, sem pista) |

Erro de uma ação (não da tela) aparece em `SnackBar` flutuante, fundo `surfaceHigh`, raio 16.

### 7.17 Logo

Ainda não existe. Até a fatia 8, usa-se um espaço reservado com o texto `VoleiIn` em `title.xl`.

### 7.18 Campo de código e reenviar (fatia 2)

- Campo de código: 6 dígitos, teclado numérico, com o mesmo visual do campo de texto (7.2). Confirma sozinho ao completar o sexto dígito. Código errado limpa o campo e mostra o erro abaixo dele.
- Reenviar código: botão de texto, desabilitado por 60 segundos depois de cada envio, com a contagem no rótulo ("Reenviar código em 45 s").

### 7.19 Onde ficam no código

Componentes comuns em `app/lib/shared/widgets/`, criados na fatia 2:

| Componente | Arquivo |
|------------|---------|
| Botões principal, destrutivo sólido e destrutivo contorno (7.1) | `buttons.dart` |
| Campo com rótulo acima e campo de senha com o olho (7.2) | `form_fields.dart` |
| Corpo de formulário que rola, com o pé da tela embaixo | `form_scroll_view.dart` |
| Barra superior interna com voltar (7.7) | `inner_app_bar.dart` |
| Avatar com foto ou iniciais (3.4) | `avatar.dart` |
| Lista de linhas com seta | `arrow_rows.dart` |
| Quadrado de ícone (7.14) | `icon_square.dart` |
| Sheet de confirmação destrutiva (7.15) | `confirm_sheet.dart` |
| Campo de código e reenviar (7.18) | `code_field.dart`, `resend_code_button.dart` |
| Frase com um valor em negrito ("Enviamos um código para **ana@...**") | `bold_value_text.dart` |
| `SnackBar` de sucesso e de erro (7.16) | `snack.dart` |
| Estados de tela (7.16) | `state_views.dart` |

## 8. Acessibilidade (RNF05)

Toda tela, antes do PR:

- [ ] Área de toque mínima de **48 × 48 dp**, inclusive nos ícones, nos botões circulares e no contador.
- [ ] Testada com a fonte do sistema em **150%**: nada cortado, nada sobreposto, sem altura fixa em componente com texto.
- [ ] Contraste mínimo de 4,5:1 para texto normal. As combinações deste documento já cumprem isso. Combinação nova precisa ser medida.
- [ ] Status sempre com texto (seção 4).
- [ ] Botão de ícone, imagem e avatar com rótulo para o TalkBack (`Semantics` ou `tooltip`).

## 9. Tema Flutter de referência

O arquivo real nasce na fatia 1, em `app/lib/core/theme/app_theme.dart`. Este é o ponto de partida.

```dart
import 'package:flutter/material.dart';

const _background = Color(0xFF0F1833);
const _surface = Color(0xFF192853);
const _surfaceHigh = Color(0xFF2A3A68);
const _onSurface = Color(0xFFECF4F7);
const _onSurfaceVariant = Color(0xFFA9B6D3);
const _primary = Color(0xFFFFE14F);
const _primaryPressed = Color(0xFFE6C835);
const _navy = Color(0xFF192853);
const _errorText = Color(0xFFFF9B90);

@immutable
class BadgeTone {
  const BadgeTone({required this.background, required this.text, required this.dot});
  final Color background;
  final Color text;
  final Color dot;
}

/// Cores de significado e de selo, que o ColorScheme do Material não tem.
/// Os blocos levam sempre texto [onBlock], nunca branco.
@immutable
class VoleiColors extends ThemeExtension<VoleiColors> {
  const VoleiColors({
    required this.game, required this.owe, required this.receive,
    required this.wait, required this.split, required this.onBlock,
    required this.primaryPressed, required this.destructive,
    required this.ok, required this.warn, required this.bad,
    required this.info, required this.waiting, required this.neutral,
  });

  final Color game, owe, receive, wait, split, onBlock, primaryPressed, destructive;
  final BadgeTone ok, warn, bad, info, waiting, neutral;

  static const dark = VoleiColors(
    game: Color(0xFFFFE14F),
    owe: Color(0xFFFF8F6B),
    receive: Color(0xFF7CDCC8),
    wait: Color(0xFFB8A6FF),
    split: Color(0xFF8EC5FF),
    onBlock: _navy,
    primaryPressed: _primaryPressed,
    destructive: Color(0xFFD93A2B),
    ok: BadgeTone(background: Color(0x2E2ECC71), text: Color(0xFF7BE3A6), dot: Color(0xFF2ECC71)),
    warn: BadgeTone(background: Color(0x2EFF9F43), text: Color(0xFFFFC48A), dot: Color(0xFFFF9F43)),
    bad: BadgeTone(background: Color(0x38E74C3C), text: Color(0xFFFF9B90), dot: Color(0xFFE74C3C)),
    info: BadgeTone(background: _surfaceHigh, text: _onSurface, dot: Color(0xFF8EC5FF)),
    waiting: BadgeTone(background: Color(0x33B8A6FF), text: Color(0xFFD3C9FF), dot: Color(0xFFB8A6FF)),
    neutral: BadgeTone(background: _surfaceHigh, text: _onSurfaceVariant, dot: _onSurfaceVariant),
  );

  static VoleiColors of(BuildContext context) => Theme.of(context).extension<VoleiColors>()!;

  @override
  VoleiColors copyWith() => this;

  // Uma base só (modo escuro): não há o que interpolar.
  @override
  VoleiColors lerp(VoleiColors? other, double t) => this;
}

// Tokens de tipografia no TextTheme:
//   displayLarge/Medium/Small  number.hero / xl / lg (Bebas Neue, só números)
//   headlineLarge/Medium       title.xl / title.lg (Montserrat 800)
//   titleLarge/Medium          title.md / title.sm (Montserrat 700)
//   bodyLarge/Medium/Small     body.lg / body.md / caption (Roboto)
//   labelLarge                 label (botões)
// number.md sai de displaySmall com copyWith(fontSize: 26).
const _text = TextTheme(
  displayLarge: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 84),
  displayMedium: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 56),
  displaySmall: TextStyle(fontFamily: 'BebasNeue', letterSpacing: 0.3, height: 1, fontSize: 40),
  headlineLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 28),
  headlineMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 22),
  titleLarge: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 18),
  titleMedium: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 15),
  // O Material 3 abre o espaçamento entre letras do texto; o design não.
  bodyLarge: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
  bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, letterSpacing: 0),
  bodySmall: TextStyle(fontSize: 12, height: 16 / 12, letterSpacing: 0),
  labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0),
);

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

final appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: _primary, onPrimary: _navy,
    secondary: _onSurface, onSecondary: _navy,
    surface: _surface, surfaceContainerHigh: _surfaceHigh,
    onSurface: _onSurface, onSurfaceVariant: _onSurfaceVariant,
    outline: _surfaceHigh, outlineVariant: _surfaceHigh,
    error: _errorText, onError: _navy,
  ),
  scaffoldBackgroundColor: _background,
  canvasColor: _background,
  dividerColor: _surfaceHigh,
  textTheme: _text.apply(bodyColor: _onSurface, displayColor: _onSurface),
  extensions: const [VoleiColors.dark],
  materialTapTargetSize: MaterialTapTargetSize.padded, // 48 dp (RNF05)
  appBarTheme: AppBarTheme(
    backgroundColor: _background,
    foregroundColor: _onSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: _text.titleLarge!.copyWith(color: _onSurface),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) return _surfaceHigh;
        if (s.contains(WidgetState.pressed)) return _primaryPressed;
        return _primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _navy,
      ),
      iconSize: const WidgetStatePropertyAll(22),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      side: const WidgetStatePropertyAll(BorderSide(color: _surfaceHigh, width: 1.5)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _onSurface,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(_text.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? _onSurfaceVariant : _primary,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: _text.bodyLarge!.copyWith(color: _onSurfaceVariant),
    errorStyle: _text.bodySmall!.copyWith(color: _errorText),
    border: _border(_surfaceHigh, 1.5),
    enabledBorder: _border(_surfaceHigh, 1.5),
    disabledBorder: _border(_surfaceHigh, 1.5),
    focusedBorder: _border(_primary, 2),
    errorBorder: _border(_errorText, 2),
    focusedErrorBorder: _border(_errorText, 2),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: _surfaceHigh,
    contentTextStyle: _text.bodyMedium!.copyWith(color: _onSurface),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
```

**Fontes:** Montserrat (700 e 800) e Bebas Neue entram como asset em `app/assets/fonts/`, declaradas no `pubspec.yaml`, para funcionar desde a primeira abertura sem baixar nada. Roboto é a do sistema. O pacote `google_fonts` não é usado. Os arquivos `.ttf` (licença OFL) podem ser copiados do v0 (`VoleiIn-v0/app/assets/fonts/`).

**`MaterialApp`:** só `theme: appTheme`, sem `darkTheme`. Sem `darkTheme`, o Flutter usa o `theme` em qualquer modo do sistema, e o app fica sempre escuro.
