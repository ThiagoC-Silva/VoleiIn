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
| `authLogout` | Sair | Botão Sair da aba Perfil (provisório na fatia 1, definitivo na fatia 2) e da tela de aceite |

### 5.4 Comuns

| Chave | Texto | Onde |
|-------|-------|------|
| `commonTryAgain` | Tentar de novo | Botão dos estados de erro e sem conexão (`design-system.md`, 7.16) |

### 5.5 Erros

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
| `email_not_confirmed` | `authEmailNotConfirmed` | `errorAuthEmailNotConfirmed` | Confirme o seu e-mail antes de entrar. |
| `over_request_rate_limit` | `authRateLimited` | `errorAuthRateLimited` | Muitas tentativas. Espere alguns minutos e tente de novo. |
| Qualquer outro | `internalError` | `errorInternalError` | Algo deu errado. Tente de novo. |

Os códigos de cadastro, recuperação de senha, troca de e-mail e login com Google estão na seção 6.8.

## 6. Fatia 2

Decisões de 12/11/2026. Telas em `docs/ui/telas.md`, seção 5.

### 6.1 Login, completado

| Chave | Texto | Onde |
|-------|-------|------|
| `authForgotPassword` | Esqueci minha senha | Botão de texto abaixo da senha |
| `authOr` | ou | Divisor entre Entrar e o Google |
| `authContinueWithGoogle` | Continuar com Google | Botão de contorno |
| `authNoAccount` | Não tem conta? | Frase do pé da tela |
| `authCreateAccount` | Criar conta | Botão de texto do pé da tela e título do cadastro |
| `authConfirmAction` | Confirmar | Ação do `SnackBar` de e-mail não confirmado |

### 6.2 Cadastro

| Chave | Texto | Onde |
|-------|-------|------|
| `authSignupSubtitle` | Crie sua conta para entrar nas listas dos seus grupos. | Frase de apoio |
| `authNameLabel` | Nome | Rótulo do campo |
| `authPasswordHint` | Pelo menos 8 caracteres | Dica abaixo da senha |
| `authCreateAccountButton` | Criar conta | Botão principal |
| `authHasAccount` | Já tem conta? | Frase do pé da tela |
| `authGoToLogin` | Entrar | Botão de texto do pé da tela |
| `authNameRequired` | Informe o seu nome. | Erro do campo vazio |
| `authNameTooLong` | O nome pode ter até 80 caracteres. | Erro do campo |
| `authPasswordTooShort` | A senha precisa ter pelo menos 8 caracteres. | Erro do campo, conferido no app |

### 6.3 Código por e-mail

Comuns à confirmação do cadastro, à recuperação de senha e à troca de e-mail.

| Chave | Texto | Onde |
|-------|-------|------|
| `authCodeLabel` | Código | Rótulo do campo |
| `authCodeSent` | Enviamos um código de 6 dígitos para {email}. | Frase com o e-mail |
| `authResendCode` | Reenviar código | Botão de texto |
| `authResendCodeIn` | Reenviar código em {seconds} s | O mesmo botão, durante a espera |
| `authCodeResent` | Enviamos um novo código. | `SnackBar` |
| `authConfirmEmailTitle` | Confirme o seu e-mail | Título da `/confirm-email` |
| `authConfirmButton` | Confirmar | Botão principal da `/confirm-email` e da troca de e-mail |
| `authConfirmEmailHelp` | Não chegou? Confira o spam. Se este e-mail já tem conta, entre ou recupere a senha. | Frase de apoio da `/confirm-email` |
| `authUseAnotherEmail` | Usar outro e-mail | Botão de texto da `/confirm-email` |

### 6.4 Recuperar senha

| Chave | Texto | Onde |
|-------|-------|------|
| `authForgotTitle` | Recuperar senha | Título |
| `authForgotSubtitle` | Informe o e-mail da sua conta. Vamos enviar um código para criar uma senha nova. | Frase da etapa 1 |
| `authSendCode` | Enviar código | Botão principal da etapa 1 e da troca de e-mail |
| `authNewPasswordLabel` | Nova senha | Rótulo do campo |
| `authSaveNewPassword` | Salvar nova senha | Botão principal da etapa 2 |
| `authPasswordChanged` | Senha alterada. | `SnackBar` da recuperação e da troca de senha |

### 6.5 Aceite dos termos

| Chave | Texto | Onde |
|-------|-------|------|
| `termsTitle` | Antes de continuar | Título da `/terms` |
| `termsSubtitleFirst` | Para usar o VoleiIn, leia e aceite os documentos abaixo. | Frase de quem nunca aceitou |
| `termsSubtitleUpdated` | Atualizamos os documentos abaixo. Leia e aceite para continuar. | Frase de quem aceitou uma versão anterior |
| `termsVersion` | Versão {version} | Subtítulo de cada documento |
| `termsCheckbox` | Li e aceito os Termos de Uso e a Política de Privacidade | Caixa de seleção |
| `termsAcceptButton` | Aceitar e continuar | Botão principal |
| `termsDocumentTermsOfUse` | Termos de Uso | Rótulo de `terms_of_use` (`modelo-dados.md`, seção 3) |
| `termsDocumentPrivacyPolicy` | Política de Privacidade | Rótulo de `privacy_policy` |
| `termsPlaceholderBody` | O texto definitivo deste documento chega antes do lançamento do app. | Corpo provisório da `/terms/:document`. Sai do ARB quando os textos jurídicos entrarem (`plan-docs.md`, seção 6.1) |

### 6.6 Perfil, edição e chave Pix

| Chave | Texto | Onde |
|-------|-------|------|
| `profileEdit` | Editar perfil | Linha do perfil e título da edição |
| `profileEditSubtitle` | Nome, apelido, foto e telefone | Subtítulo da linha |
| `profilePix` | Chave Pix | Linha do perfil e título da tela |
| `profilePixNone` | Não cadastrada | Subtítulo da linha sem chave |
| `profilePixSummary` | {type} · {key} | Subtítulo da linha com chave, já formatada |
| `profileChangeEmail` | Trocar e-mail | Linha do perfil e título da tela |
| `profileChangePassword` | Trocar senha | Linha do perfil e título da tela |
| `profileChangePhoto` | Trocar foto | Botão de texto da edição |
| `profilePhotoGallery` | Escolher da galeria | Opção da sheet |
| `profilePhotoCamera` | Tirar foto | Opção da sheet |
| `profilePhotoRemove` | Remover foto | Opção da sheet |
| `profileNicknameLabel` | Apelido | Rótulo do campo |
| `profileNicknameHint` | Aparece no lugar do nome nas listas | Dica do campo |
| `profileNicknameTooLong` | O apelido pode ter até 30 caracteres. | Erro do campo |
| `profilePhoneLabel` | Telefone | Rótulo do campo |
| `profilePhoneInvalid` | Informe o DDD e o número, com 10 ou 11 dígitos. | Erro do campo |
| `profilePhoneVisible` | Mostrar meu telefone | Interruptor |
| `profilePhoneVisibleHint` | Quem estiver nos seus grupos e jogos poderá ver | Dica do interruptor |
| `commonSave` | Salvar | Botão principal da edição, da chave Pix e da troca de senha |
| `profileSaved` | Perfil salvo. | `SnackBar` |
| `pixTypeLabel` | Tipo da chave | Rótulo dos chips |
| `pixTypeCpf` | CPF | Rótulo de `cpf` |
| `pixTypeCnpj` | CNPJ | Rótulo de `cnpj` |
| `pixTypeEmail` | E-mail | Rótulo de `email` |
| `pixTypePhone` | Telefone | Rótulo de `phone` |
| `pixTypeRandom` | Aleatória | Rótulo de `random` |
| `pixKeyLabel` | Chave | Rótulo do campo |
| `pixInvalidCpf` | CPF inválido. Confira os números. | Erro do campo |
| `pixInvalidCnpj` | CNPJ inválido. Confira as letras e os números. | Erro do campo. O CNPJ pode ter letras (formato alfanumérico da Receita) |
| `pixInvalidEmail` | E-mail inválido. | Erro do campo |
| `pixInvalidPhone` | Informe o DDD e o número, com 10 ou 11 dígitos. | Erro do campo |
| `pixInvalidRandom` | Chave aleatória inválida. Copie e cole a chave do seu banco. | Erro do campo |
| `pixSaved` | Chave Pix salva. | `SnackBar` |
| `pixRemove` | Remover chave | Botão destrutivo de contorno |
| `pixRemoveTitle` | Remover a chave Pix? | Título da confirmação |
| `pixRemoveBody` | Sem chave Pix, você não pode ser recebedor de jogos. | Frase da confirmação |
| `pixRemoveConfirm` | Remover | Botão destrutivo sólido da confirmação |
| `commonBack` | Voltar | Botão de contorno das confirmações |

### 6.7 Trocar e-mail e senha

| Chave | Texto | Onde |
|-------|-------|------|
| `emailCurrent` | E-mail atual: {email} | Texto da etapa 1 |
| `emailNewLabel` | Novo e-mail | Rótulo do campo |
| `emailKeepsWorking` | Até você digitar o código, o e-mail atual continua valendo. | Frase da etapa 1 |
| `emailSameAsCurrent` | Este já é o seu e-mail. | Erro do campo |
| `emailChanged` | E-mail alterado. | `SnackBar` |
| `passwordCurrentLabel` | Senha atual | Rótulo do campo |
| `passwordCurrentWrong` | Senha atual incorreta. | Erro do campo, no lugar de `errorAuthInvalidCredentials` |

### 6.8 Erros

**Supabase Auth.** Acrescenta à tabela da seção 5.5:

| Código do Supabase Auth | `ErrorCode` | Chave | Texto |
|-------------------------|-------------|-------|-------|
| `weak_password` | `authWeakPassword` | `errorAuthWeakPassword` | A senha precisa ter pelo menos 8 caracteres. |
| `otp_expired` | `authInvalidCode` | `errorAuthInvalidCode` | Código incorreto ou vencido. Confira ou peça um novo. |
| `email_address_invalid` | `authInvalidEmail` | `errorAuthInvalidEmail` | Confira o e-mail informado. |
| `email_exists`, `user_already_exists` | `authEmailInUse` | `errorAuthEmailInUse` | Este e-mail já é usado por outra conta. |
| `same_password` | `authSamePassword` | `errorAuthSamePassword` | A nova senha precisa ser diferente da atual. |
| `over_email_send_rate_limit` | `authEmailRateLimited` | `errorAuthEmailRateLimited` | Muitos e-mails enviados. Espere alguns minutos e tente de novo. |

- O Supabase Auth devolve `otp_expired` tanto para código errado quanto para código vencido, por isso o texto cobre os dois.
- **Google** (só do app): a pessoa fechar o seletor não é erro e não mostra nada. Qualquer outra falha do `google_sign_in` vira `authGoogleFailed`, chave `errorAuthGoogleFailed`: "Não foi possível entrar com o Google. Tente de novo."

**Banco e Storage**

| Origem | `ErrorCode` | Chave | Texto |
|--------|-------------|-------|-------|
| `PIX_KEY_IN_USE` (*trigger* da RN105) | `pixKeyInUse` | `errorPixKeyInUse` | Você pode trocar a chave, mas não removê-la enquanto tiver jogos em aberto ou valores a receber. |
| Storage, arquivo acima do limite do bucket (HTTP 413) | `photoTooLarge` | `errorPhotoTooLarge` | A foto passa de 2 MB. Escolha outra. |
| Storage, tipo fora da lista do bucket (`invalid_mime_type`), ou tipo recusado no app | `photoInvalidType` | `errorPhotoInvalidType` | Use uma foto JPEG, PNG ou WebP. |

### 6.9 E-mails do Supabase Auth

Saem pelo Resend, com o remetente `nao-responda@mail.voleiin.com.br` (`setup.md`, seção 10). Os modelos ficam em `supabase/templates/` e são configurados no `config.toml` e no painel (`setup.md`, seção 6.1). `{{ .Token }}` é o código de 6 dígitos (ADR 0017). Texto simples em HTML mínimo, sem imagem, para não cair no spam.

| Modelo | Arquivo | Assunto | Corpo |
|--------|---------|---------|-------|
| Confirmação do cadastro | `confirmation.html` | Seu código do VoleiIn: {{ .Token }} | Olá! Use o código **{{ .Token }}** para confirmar o seu e-mail no VoleiIn. Ele vale por 1 hora. Se você não criou uma conta, ignore este e-mail. |
| Recuperação de senha | `recovery.html` | Código para criar uma senha nova: {{ .Token }} | Use o código **{{ .Token }}** no app para criar uma senha nova. Ele vale por 1 hora. Se você não pediu, ignore este e-mail: a sua senha continua a mesma. |
| Troca de e-mail | `email_change.html` | Confirme o seu novo e-mail: {{ .Token }} | Use o código **{{ .Token }}** no app para confirmar este endereço como o novo e-mail da sua conta no VoleiIn. Ele vale por 1 hora. Se você não pediu, ignore este e-mail. |

O código vai também no assunto para aparecer na notificação do celular, e a pessoa não precisar abrir o e-mail.
