# Catálogo de Textos

> Decisões de 09/11/2026. Base: `contratos-api.md` (seção 2), `arquitetura-app.md` (seções 7, 8 e 10), `requisitos-nao-funcionais.md` (RNF06) e `docs/ui/telas.md`.
> Todos os textos de interface do app, em pt-BR. O código não escreve texto: lê do `app/lib/l10n/app_pt.arb` pela chave daqui (`arquitetura-app.md`, seção 10).
> O catálogo cresce a cada fatia, só com os textos que ela usa (`plan-docs.md`, seção 8.3).

## 1. Como usar

- Cada linha das tabelas da seção 5 em diante vira uma entrada do `app_pt.arb`, com a mesma chave e o mesmo texto.
- **Chave:** em inglês e `camelCase`, prefixada pela feature ou pela área (`auth`, `nav`, `common`). Erros usam `error` mais o código em `camelCase` (`NOT_FOUND` → `errorNotFound`).
- **Valores variáveis** usam *placeholders* do ARB (`{amount}`, `{name}`). O valor chega já formatado (seção 3).
- Texto novo ou alterado entra aqui antes de entrar no ARB. Se o código e este documento divergirem, vale este documento.

## 2. Tom de voz

- Informal, curto, tratando por **você**. Frases de uma linha sempre que possível.
- A mensagem diz o que aconteceu e, quando houver, o que fazer: "Espere alguns minutos e tente de novo."
- Sem gíria, sem exclamação em erro e sem culpar a pessoa ("Você errou a senha" → "E-mail ou senha incorretos").
- Sem termo técnico: nada de "token", "servidor", "sessão", "RLS" ou código de erro na tela.
- Nomes do domínio iguais aos do glossário (`regras-negocio.md`, seção 1) e aos rótulos dos enums (`modelo-dados.md`, seção 3): "valor a pagar", "recebedor", "lista de espera", "Em análise".
- Botões com verbo no infinitivo ("Entrar", "Tentar de novo", "Sair").

## 3. Formatos

Funções em `app/lib/core/format/` (`arquitetura-app.md`, seção 8). Os casos de teste estão em `testes-referencia.md`, seção 9.3.

| O quê | Formato | Exemplo |
|-------|---------|---------|
| Dinheiro (`formatCents`) | `R$`, espaço sem quebra (U+00A0), milhar com ponto, duas casas com vírgula | `R$ 1.234,56` |
| Data (`formatDate`) | `dd/mm/aaaa` em `America/Fortaleza` | `09/11/2026` |
| Hora (`formatTime`) | `HH:mm`, 24 horas, em `America/Fortaleza` | `20:00` |
| Data curta (`formatShortDate`) | Dia da semana abreviado, vírgula, `dd/mm` | `qui, 22/10` |

- **Dias da semana abreviados**, sempre em minúsculas e sem ponto: `dom`, `seg`, `ter`, `qua`, `qui`, `sex`, `sáb`. A lista é fixa no código, sem depender do `intl`, que põe ponto depois da abreviação.
- O espaço sem quebra impede que `R$` fique numa linha e o número em outra.
- **Valor negativo** (o "por conta" do cenário R04, `testes-referencia.md`): o formato é decidido no catálogo da fatia 5.

## 4. Textos que não são de interface

Não entram no ARB e podem ficar no código, em inglês:

- mensagens para quem desenvolve: `assert`, `StateError`, logs, nomes de teste;
- a parada na abertura por variável de ambiente ausente (`setup.md`, seção 5.1). O usuário nunca a vê, porque o build de produção é gerado pelo pipeline com todas as variáveis.

## 5. Fatia 1

### 5.1 App e navegação

| Chave | Texto | Onde |
|-------|-------|------|
| `appTitle` | VoleiIn | Nome do app no `MaterialApp` e no espaço reservado do logo |
| `navGames` | Jogos | Aba 1 |
| `navGroups` | Grupos | Aba 2 |
| `navCharges` | Cobranças | Aba 3 |
| `navProfile` | Perfil | Aba 4 |

### 5.2 Abas vazias (provisório)

Saem do ARB quando a aba ganha a tela real (`docs/ui/telas.md`, seção 4.2).

| Chave | Texto | Onde |
|-------|-------|------|
| `placeholderTitle` | Em construção | Título do estado vazio das quatro abas |
| `placeholderBody` | Esta parte do app chega nas próximas versões. | Frase do estado vazio |

### 5.3 Login

| Chave | Texto | Onde |
|-------|-------|------|
| `authLoginSubtitle` | Entre para ver seus jogos. | Subtítulo do login |
| `authEmailLabel` | E-mail | Rótulo do campo |
| `authPasswordLabel` | Senha | Rótulo do campo |
| `authShowPassword` | Mostrar senha | Rótulo do botão de ícone, para o TalkBack |
| `authHidePassword` | Ocultar senha | Rótulo do botão de ícone, para o TalkBack |
| `authLoginButton` | Entrar | Botão principal |
| `authEmailRequired` | Informe o seu e-mail. | Erro do campo vazio |
| `authPasswordRequired` | Informe a sua senha. | Erro do campo vazio |
| `authLogout` | Sair | Botão provisório na aba Perfil |

### 5.4 Erros

Cada `ErrorCode` do app tem um texto (`arquitetura-app.md`, seção 7). Na fatia 1 entram os códigos gerais do `contratos-api.md` (seção 2), o de sem conexão e os do login. Cada fatia acrescenta os seus.

**Gerais**

| Código | Chave | Texto |
|--------|-------|-------|
| `NOT_AUTHENTICATED` | `errorNotAuthenticated` | Entre na sua conta para continuar. |
| `NOT_FOUND` | `errorNotFound` | Não encontramos o que você procura. |
| `INVALID_INPUT` | `errorInvalidInput` | Confira os dados informados. |
| `INTERNAL_ERROR` | `errorInternalError` | Algo deu errado. Tente de novo. |
| `noConnection` (só do app) | `errorNoConnection` | Sem conexão com a internet. Confira a sua rede e tente de novo. |

**Login.** O Supabase Auth devolve um `AuthException` com um código em texto. A conversão (`arquitetura-app.md`, seção 7) usa esta tabela:

| Código do Supabase Auth | `ErrorCode` | Chave | Texto |
|-------------------------|-------------|-------|-------|
| `invalid_credentials` | `authInvalidCredentials` | `errorAuthInvalidCredentials` | E-mail ou senha incorretos. |
| `email_not_confirmed` | `authEmailNotConfirmed` | `errorAuthEmailNotConfirmed` | Confirme o seu e-mail antes de entrar. O link está na sua caixa de entrada. |
| `over_request_rate_limit` | `authRateLimited` | `errorAuthRateLimited` | Muitas tentativas. Espere alguns minutos e tente de novo. |
| Qualquer outro | `internalError` | `errorInternalError` | Algo deu errado. Tente de novo. |

Os códigos de cadastro, recuperação de senha, troca de e-mail e login com Google entram na fatia 2.
