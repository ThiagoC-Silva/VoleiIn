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
- **Valor negativo** (o "por conta" do cenário R04, `testes-referencia.md`): `formatCents` não aceita negativo. A tela troca a linha pela frase `splitReceiverExtra` com o valor absoluto (seção 9, decisão de 18/11/2026).

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

Saem do ARB quando a aba ganha a tela real (`docs/ui/telas.md`, seção 4.2). Saíram na etapa C da fatia 5, quando Cobranças, a última aba vazia, ganhou a tela real.

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

## 7. Fatia 3

Decisões de 15/11/2026. Telas em `docs/ui/telas.md`, seção 6. A palavra do domínio é **solicitação** (`join_request_status`, `modelo-dados.md`, seção 3); o verbo dos botões é **pedir** ("Pedir para entrar").

**Plurais** usam a sintaxe ICU do ARB: `{count, plural, =1{1 integrante} other{{count} integrantes}}`. Nas tabelas abaixo, a forma do singular vem antes da barra e a do plural depois.

Os textos provisórios da seção 5.2 continuam no ARB: as abas Jogos e Cobranças ainda os usam.

### 7.1 Meus grupos

| Chave | Texto | Onde |
|-------|-------|------|
| `groupsCreate` | Criar grupo | Botão de Meus grupos, título e botão principal da criação |
| `groupsJoin` | Entrar com código | Botão de Meus grupos e título da entrada por código |
| `groupsEmptyTitle` | Você ainda não está em nenhum grupo | Título do estado vazio |
| `groupsEmptyBody` | Crie um grupo ou peça para entrar com o código de convite. | Frase do estado vazio |
| `groupsMemberCount` | 1 integrante / {count} integrantes | Subtítulo da linha do grupo (plural) |
| `groupsPendingCount` | 1 solicitação / {count} solicitações | Acrescentado ao subtítulo, só para admins (plural) |
| `groupsRowSubtitle` | {members} · {pending} | Subtítulo com as duas partes, já formatadas |
| `groupRoleAdmin` | Admin | Selo do papel. Rótulo de `group_role.admin` |
| `groupPhotoLabel` | Foto do grupo {name} | Rótulo do avatar do grupo, para o TalkBack |

### 7.2 Criar e editar grupo

| Chave | Texto | Onde |
|-------|-------|------|
| `groupNameLabel` | Nome do grupo | Rótulo do campo |
| `groupNameRequired` | Informe o nome do grupo. | Erro do campo vazio |
| `groupNameTooLong` | O nome pode ter até 60 caracteres. | Erro do campo |
| `groupChoosePhoto` | Escolher foto | Botão de texto da criação |
| `groupCreated` | Grupo criado. | `SnackBar` |
| `groupCreatedPhotoFailed` | Grupo criado, mas a foto não foi salva. Tente de novo em Editar grupo. | `SnackBar` |
| `groupEdit` | Editar grupo | Linha do detalhe e título da edição |
| `groupEditSubtitle` | Nome e foto | Subtítulo da linha |
| `groupSaved` | Grupo salvo. | `SnackBar` |
| `groupDelete` | Excluir grupo | Botão destrutivo de contorno e botão da confirmação |
| `groupDeleteTitle` | Excluir o grupo {name}? | Título da confirmação |
| `groupDeleteBody` | Todos os integrantes saem do grupo, as solicitações pendentes são canceladas e o convite deixa de valer. Os jogos concluídos e cancelados continuam no histórico de quem participou. | Frase da confirmação |
| `groupDeleted` | Grupo excluído. | `SnackBar` |

- A troca de foto usa as chaves da fatia 2: `profileChangePhoto` (Trocar foto), `profilePhotoGallery`, `profilePhotoCamera` e `profilePhotoRemove`. O botão Salvar usa `commonSave`, e o voltar das confirmações, `commonBack`.

### 7.3 Entrar com código

| Chave | Texto | Onde |
|-------|-------|------|
| `groupJoinIntro` | Digite ou cole o código que você recebeu do grupo. | Frase da etapa 1 |
| `groupJoinCodeLabel` | Código do convite | Rótulo do campo |
| `groupJoinCodeRequired` | Informe o código. | Erro do campo vazio |
| `groupJoinCodeInvalid` | O código tem 12 letras e números. Confira e tente de novo. | Erro do campo, sem chamar o servidor |
| `groupJoinContinue` | Continuar | Botão principal da etapa 1 |
| `groupJoinApprovalNeeded` | Um admin do grupo precisa aprovar a sua entrada. | Frase do estado "Pode pedir" |
| `groupJoinRequest` | Pedir para entrar | Botão principal |
| `groupJoinPending` | Solicitação enviada. Aguardando a aprovação de um admin. | Aviso em linha |
| `groupJoinPendingHint` | O grupo aparece em Meus grupos quando a solicitação for aprovada. | Frase abaixo do aviso |
| `groupJoinBackToGroups` | Voltar aos grupos | Botão de contorno |
| `groupJoinAlreadyMember` | Você já é membro deste grupo. | Frase do estado "Já é membro" |
| `groupJoinOpen` | Abrir o grupo | Botão principal |
| `groupJoinOtherCode` | Usar outro código | Botão de texto da etapa 2 |

### 7.4 Detalhe do grupo e convite

| Chave | Texto | Onde |
|-------|-------|------|
| `groupMembers` | Integrantes | Linha do detalhe e título da tela |
| `groupMembersSubtitle` | 1 pessoa / {count} pessoas | Subtítulo da linha (plural) |
| `groupRequests` | Solicitações | Linha do detalhe e título da tela |
| `groupRequestsSubtitle` | Nenhuma solicitação pendente / 1 solicitação pendente / {count} solicitações pendentes | Subtítulo da linha (plural, com `=0`) |
| `groupInvite` | Convite | Linha do detalhe |
| `groupInviteActive` | Código ativo | Subtítulo da linha |
| `groupInviteInactive` | Convite desativado | Subtítulo da linha |
| `groupLeave` | Sair do grupo | Botão destrutivo de contorno e botão da confirmação |
| `groupLeaveTitle` | Sair do grupo {name}? | Título da confirmação |
| `groupLeaveBody` | Para voltar, você vai precisar do código e da aprovação de um admin. | Frase da confirmação |
| `groupLeft` | Você saiu do grupo. | `SnackBar` |
| `groupInviteTitle` | Convite do grupo | Título da sheet |
| `groupInviteIntro` | Quem tiver o código pode pedir para entrar. Um admin aprova cada solicitação. | Frase da sheet |
| `groupInviteShare` | Compartilhar | Botão principal |
| `groupInviteShareText` | Entre no grupo {name} no VoleiIn. No app, toque em Grupos, depois em Entrar com código, e use o código: {code} | Texto enviado pelo compartilhamento do Android. O código fica no fim, sozinho, para ser fácil de copiar |
| `groupInviteCopy` | Copiar código | Botão de contorno |
| `groupInviteCopied` | Código copiado. | `SnackBar` |
| `groupInviteRegenerate` | Gerar novo código | Botão de texto (admin) e botão da confirmação |
| `groupInviteRegenerateTitle` | Gerar um novo código? | Título da confirmação |
| `groupInviteRegenerateBody` | O código atual deixa de funcionar. As solicitações já feitas continuam valendo. | Frase da confirmação |
| `groupInviteRegenerated` | Novo código gerado. | `SnackBar` |
| `groupInviteDisable` | Desativar convite | Botão de texto destrutivo (admin) |
| `groupInviteDisableTitle` | Desativar o convite? | Título da confirmação |
| `groupInviteDisableBody` | Ninguém consegue pedir para entrar até um admin gerar um novo código. As solicitações já feitas continuam valendo. | Frase da confirmação |
| `groupInviteDisableConfirm` | Desativar | Botão destrutivo sólido da confirmação |
| `groupInviteDisabled` | Convite desativado. | `SnackBar` |
| `groupInviteOff` | O convite está desativado. | Frase da sheet sem código |
| `groupInviteGenerate` | Gerar código | Botão principal da sheet sem código (admin) |
| `groupInviteAskAdmin` | Peça a um admin para gerar um novo código. | Frase da sheet sem código (membro) |

### 7.5 Integrantes e solicitações

| Chave | Texto | Onde |
|-------|-------|------|
| `groupMemberYou` | {name} (você) | Nome da própria pessoa nas listas |
| `groupMemberJoinedAt` | Entrou em {date} | Subtítulo da linha (`formatDate`) |
| `groupMemberViewProfile` | Ver perfil | Opção da sheet do admin |
| `groupMemberMakeAdmin` | Tornar admin | Opção da sheet do admin |
| `groupMemberMakeMember` | Deixar como membro | Opção da sheet do admin |
| `groupMemberRemove` | Remover do grupo | Opção destrutiva da sheet do admin |
| `groupMemberRemoveTitle` | Remover {name} do grupo? | Título da confirmação |
| `groupMemberRemoveBody` | {name} deixa de ver o grupo. Para voltar, vai precisar do código e da aprovação de um admin. | Frase da confirmação |
| `groupMemberRemoveConfirm` | Remover | Botão destrutivo sólido da confirmação |
| `groupMemberRemoved` | Removemos {name} do grupo. | `SnackBar` |
| `groupMemberNowAdmin` | {name} agora é admin. | `SnackBar` |
| `groupMemberNowMember` | {name} agora é membro. | `SnackBar` |
| `groupStepDown` | Deixar de ser admin | Opção da sheet e botão da confirmação |
| `groupStepDownTitle` | Deixar de ser admin? | Título da confirmação |
| `groupStepDownBody` | Só outro admin poderá devolver esse papel a você. | Frase da confirmação |
| `groupSteppedDown` | Você agora é membro. | `SnackBar` |
| `groupRequestAsked` | Pediu em {date} | Subtítulo da solicitação (`formatShortDate`) |
| `groupRequestApprove` | Aprovar | Ação da linha |
| `groupRequestReject` | Recusar | Ação da linha |
| `groupRequestApproved` | {name} entrou no grupo. | `SnackBar` |
| `groupRequestRejected` | Solicitação recusada. | `SnackBar` |
| `groupRequestsEmptyTitle` | Nenhuma solicitação pendente | Título do estado vazio |
| `groupRequestsEmptyBody` | Quando alguém pedir para entrar com o código, a solicitação aparece aqui. | Frase do estado vazio |

### 7.6 Perfil de outra pessoa

Sem texto novo. O título é o `display_name`, e o estado "não encontrado" usa `errorNotFound` (seção 5.5).

### 7.7 Erros

Códigos das funções de grupo e da prévia do convite (`contratos-api.md`, seção 2). O texto final é este, e não a mensagem inicial do contrato. `MEMBER_IS_RECEIVER` e `MEMBER_IS_ONLY_GAME_ADMIN` estão na seção 8.8, com a RN16.

| Código | `ErrorCode` | Chave | Texto |
|--------|-------------|-------|-------|
| `NOT_A_MEMBER` | `notAMember` | `errorNotAMember` | Você não é membro deste grupo. |
| `NOT_GROUP_ADMIN` | `notGroupAdmin` | `errorNotGroupAdmin` | Só um admin do grupo pode fazer isso. |
| `INVITE_INVALID` | `inviteInvalid` | `errorInviteInvalid` | Este código não vale. Confira ou peça um novo ao grupo. |
| `ALREADY_MEMBER` | `alreadyMember` | `errorAlreadyMember` | Você já é membro deste grupo. |
| `JOIN_REQUEST_PENDING` | `joinRequestPending` | `errorJoinRequestPending` | Você já pediu para entrar neste grupo. Aguarde a aprovação de um admin. |
| `REQUEST_NOT_PENDING` | `requestNotPending` | `errorRequestNotPending` | Esta solicitação já foi decidida. |
| `TARGET_NOT_MEMBER` | `targetNotMember` | `errorTargetNotMember` | Esta pessoa não é mais membro do grupo. |
| `CANNOT_REMOVE_SELF` | `cannotRemoveSelf` | `errorCannotRemoveSelf` | Para sair, use a opção Sair do grupo. |
| `LAST_ADMIN` | `lastAdmin` | `errorLastAdmin` | Promova outro admin antes. O grupo precisa de ao menos um. |
| `GROUP_HAS_ACTIVE_GAMES` | `groupHasActiveGames` | `errorGroupHasActiveGames` | O grupo ainda tem jogos Abertos ou Confirmados. |

- A prévia do convite é uma Edge Function: o erro chega como `FunctionException`, com o código em `error.code` (`contratos-api.md`, seção 1), e passa pela mesma tabela.

## 8. Fatia 4

Decisões de 16/11/2026. Telas em `docs/ui/telas.md`, seção 7. As palavras do domínio seguem o glossário: **lista** (de presença), **lista de espera**, **vaga**, **limite de vagas**, **prazo de cancelamento**, **recebedor**. O verbo dos botões é **entrar** e **sair** ("Entrar na lista", "Sair da lista de espera").

Os textos provisórios da seção 5.2 continuam no ARB: a aba Cobranças ainda os usa. Os plurais seguem a sintaxe ICU da seção 7.

### 8.1 Meus jogos e card de jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `gamesFilterUpcoming` | Próximos | Chip de Meus jogos |
| `gamesFilterPast` | Anteriores | Chip de Meus jogos |
| `gamesCreate` | Criar jogo | Botão de Meus jogos e do detalhe do grupo, título e botão principal da criação |
| `gamesEmptyUpcomingTitle` | Nenhum jogo marcado | Título do estado vazio de Próximos |
| `gamesEmptyUpcomingBody` | Crie um jogo ou espere alguém dos seus grupos marcar um. | Frase do estado vazio de Próximos |
| `gamesEmptyPastTitle` | Nenhum jogo anterior | Título do estado vazio de Anteriores |
| `gamesEmptyPastBody` | Os jogos concluídos e cancelados aparecem aqui. | Frase do estado vazio de Anteriores |
| `gameStandalone` | Avulso | No lugar do nome do grupo, no card e no topo do detalhe |
| `gameSlotsCount` | {occupied}/{limit} | Vagas no card e no trio do detalhe |
| `gameSlotsUnit` | vagas | Palavra depois das vagas no card e dentro do anel do topo (decisão de 16/11/2026, `games.png` e `game.png`) |
| `gameStatusOpen` | Aberto | Pílula. Rótulo de `game_status.open` |
| `gameStatusConfirmed` | Confirmado | Pílula. Rótulo de `game_status.confirmed` |
| `gameStatusCancelled` | Cancelado | Selo. Rótulo de `game_status.cancelled` |
| `gameStatusCompleted` | Concluído | Pílula. Rótulo de `game_status.completed` |
| `gameInProgress` | Em andamento | Selo de tempo |
| `gameAwaitingCompletion` | Aguardando conclusão | Selo de tempo |
| `gameOnList` | Na lista | Selo da situação da pessoa. Rótulo de `participant_status.active` |
| `gameLeftAfterStartBadge` | Saiu após o início | Selo da situação e da linha da lista. Rótulo de `participant_status.left_after_start` |
| `gameWaitlistPosition` | {position}º na espera | Selo da posição na espera |
| `gameCardLabel` | Jogo {group}, {date} às {time}, {location}, {status} | Rótulo do card para o TalkBack |

### 8.2 Criar e editar jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `gamePixNeededBody` | Quem cria o jogo é o recebedor: quem entrar na lista paga a você. Cadastre uma chave Pix para continuar. | Aviso em linha sem chave Pix |
| `gamePixNeededAction` | Cadastrar chave Pix | Botão de contorno do aviso |
| `gameGroupLabel` | Grupo | Rótulo do campo |
| `gameGroupPlaceholder` | Escolha o grupo | Campo vazio |
| `gameGroupRequired` | Escolha o grupo do jogo. | Erro do campo vazio |
| `gameGroupSheetTitle` | Onde é o jogo? | Título da sheet de grupos |
| `gameGroupStandaloneHint` | Num jogo avulso, só entra quem receber o convite do jogo. | Dica do campo com Avulso |
| `gameLocationLabel` | Nome do local | Rótulo do campo |
| `gameLocationRequired` | Informe o local. | Erro do campo vazio |
| `gameLocationTooLong` | O local pode ter até 120 caracteres. | Erro do campo |
| `gameMapsLabel` | Link do Google Maps (opcional) | Rótulo do campo |
| `gameMapsHint` | Cole o link do local no Google Maps. | Dica do campo |
| `gameMapsInvalid` | O link precisa começar com https://. | Erro do campo |
| `gameDateLabel` | Data do jogo | Rótulo do campo |
| `gameStartLabel` | Início | Rótulo do campo |
| `gameEndLabel` | Fim | Rótulo do campo |
| `gameDateRequired` | Escolha a data. | Erro do campo vazio |
| `gameTimeRequired` | Escolha o horário. | Erro do campo vazio |
| `gameEndsNextDay` | Termina {date}. | Dica do fim mais cedo que o início (`formatShortDate`) |
| `gameEndSameAsStart` | O fim precisa ser depois do início. | Erro do campo |
| `gameStartInPast` | O início precisa estar no futuro. | Erro do campo |
| `gameDeadlineLabel` | Prazo de cancelamento | Rótulo dos campos de data e hora do prazo |
| `gameDeadlineHint` | Até esse horário, quem sair da lista não paga multa. | Dica do prazo |
| `gameDeadlineAfterStart` | O prazo não pode passar do início do jogo. | Erro do campo |
| `gameTotalLabel` | Valor total do espaço | Rótulo do campo |
| `gameTotalRequired` | Informe o valor total. | Erro do campo vazio ou com R$ 0,00 |
| `gameSlotLimitLabel` | Limite de vagas | Rótulo do contador |
| `gameSlotLimitRequired` | Informe o limite de vagas. | Erro do contador vazio |
| `gameSlotLimitDecrease` | Diminuir vagas | Rótulo do botão − para o TalkBack |
| `gameSlotLimitIncrease` | Aumentar vagas | Rótulo do botão + para o TalkBack |
| `gameEstimate` | Cerca de {amount} por pessoa | Aviso da estimativa (`formatCents`) |
| `gameEstimateHint` | É só uma estimativa. A divisão final é feita na conclusão do jogo. | Frase do aviso da estimativa |
| `gameReceiverNotice` | Você vai ser o recebedor deste jogo. Quem entrar na lista vê a sua chave Pix. | Aviso do recebedor |
| `gameCreated` | Jogo criado. | `SnackBar` |
| `gameEdit` | Editar jogo | Opção do menu e título da edição |
| `gameSlotsOccupiedHint` | 1 pessoa na lista / {count} pessoas na lista | Dica do contador na edição (plural) |
| `gameSaved` | Jogo salvo. | `SnackBar` |
| `gameEditStarted` | O jogo já começou. Depois do início, os dados não mudam. | Aviso no lugar do formulário |

- O botão Salvar usa `commonSave`.

### 8.3 Detalhe do jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `gameMenuLabel` | Opções do jogo | Rótulo do botão `more_vert` para o TalkBack |
| `gameOpenMaps` | Abrir no Maps | Rótulo do botão do mapa |
| `gameTimeRange` | {start} – {end} | Horário no topo (`formatTime`) |
| `gameTrioSlots` | Vagas | Rótulo do trio |
| `gameTrioPerPerson` | Por pessoa | Rótulo do trio |
| `gameTrioDeadline` | Prazo | Rótulo do trio |
| `gameTrioFreeSlots` | 1 livre / {count} livres | Linha de apoio das vagas no trio, com vaga (plural; decisão de 16/11/2026, `game.png`) |
| `gameTrioFull` | lista cheia | Linha de apoio das vagas no trio, sem vaga (`game-confirmado.png`) |
| `gameTrioEstimate` | estimativa | Linha de apoio do valor por pessoa no trio (`game.png`) |
| `gameDateTime` | {date}, {time} | Prazo no trio e nas frases (`formatShortDate` e `formatTime`) |
| `gameReceiver` | Recebedor | Selo e título do bloco do recebedor |
| `gameAdmin` | Admin | Selo do admin do jogo na lista |
| `gamePixCopy` | Copiar chave | Botão de texto do bloco do recebedor |
| `gamePixCopied` | Chave Pix copiada. | `SnackBar` |
| `gamePixOnlyParticipants` | A chave Pix do recebedor aparece para quem está na lista. | Frase do bloco do recebedor |
| `gameListTitle` | Lista · {occupied} de {limit} | Título da lista de presença |
| `gameWaitlistTitle` | Lista de espera · {count} | Título da lista de espera |
| `gameJoin` | Entrar na lista | Botão principal |
| `gameJoinWaitlist` | Entrar na lista de espera | Botão principal |
| `gameFullHint` | A lista está cheia. Na espera, você é avisado quando abrir uma vaga. | Frase acima do botão da espera |
| `gameNeedsInvite` | Para entrar neste jogo, você precisa do convite dele. | Frase do pé para quem não é membro do grupo ou num jogo avulso |
| `gameLeaveWaitlist` | Sair da lista de espera | Botão de texto ou de contorno |
| `gameWaitlistNotice` | Você é o {position}º na espera. Quando abrir uma vaga, ela fica com quem entrar primeiro. | Aviso em linha de quem está na espera (RN53) |
| `gameReceiverCannotLeave` | Você é o recebedor deste jogo e não pode sair da lista. Se não puder jogar, um admin precisa indicar outro recebedor antes. | Aviso em linha do recebedor (RN29). Texto da fatia 5, com a troca de recebedor |
| `gameListLocked` | A lista está travada até a conclusão do jogo. | Aviso em linha depois do fim (RN57) |
| `gameJoined` | Você entrou na lista. | `SnackBar` |
| `gameJoinedWaitlist` | Você entrou na lista de espera. | `SnackBar` |
| `gameLeftWaitlist` | Você saiu da lista de espera. | `SnackBar` |

### 8.4 Sair, remover e cancelar

| Chave | Texto | Onde |
|-------|-------|------|
| `gameLeave` | Sair da lista | Botão destrutivo de contorno e botão da confirmação |
| `gameLeaveTitle` | Sair da lista? | Título da confirmação |
| `gameLeaveOnTimeBody` | Saindo até {deadline}, você não paga multa, e a vaga fica livre para outra pessoa. | Frase da confirmação antes do prazo (`gameDateTime`) |
| `gameLeaveLateBody` | O prazo de cancelamento já passou. A saída pode gerar uma multa igual à parte por vaga, decidida na conclusão do jogo. | Frase da confirmação entre o prazo e o início |
| `gameLeaveAfterStartBody` | O jogo já começou. A saída fica registrada como falta, com multa igual à parte por vaga, e a vaga continua contando. | Frase da confirmação em andamento |
| `gameLeftOnTime` | Você saiu da lista, sem multa. | `SnackBar` do `outcome` `cancelled_on_time` |
| `gameLeftLate` | Você saiu da lista depois do prazo. A multa é decidida na conclusão do jogo. | `SnackBar` do `outcome` `cancelled_late` |
| `gameLeftAfterStart` | Você saiu do jogo. A falta ficou registrada. | `SnackBar` do `outcome` `left_after_start` |
| `gameParticipantRemove` | Remover da lista | Opção destrutiva da sheet do admin |
| `gameParticipantRemoveTitle` | Remover {name} da lista? | Título da confirmação |
| `gameParticipantRemoveBody` | {name} sai da lista sem multa, e a vaga fica livre para outra pessoa. | Frase da confirmação (RN58) |
| `gameParticipantRemoveConfirm` | Remover | Botão destrutivo sólido da confirmação |
| `gameParticipantRemoved` | Removemos {name} da lista. | `SnackBar` |
| `gameCancel` | Cancelar jogo | Opção destrutiva do menu e botão da confirmação |
| `gameCancelTitle` | Cancelar o jogo? | Título da confirmação |
| `gameCancelBody` | O jogo não acontece e ninguém paga nada. Quem está na lista e na espera é avisado. Não dá para desfazer. | Frase da confirmação (RN43, RN67, RN114) |
| `gameCancelled` | Jogo cancelado. | `SnackBar` |

- A sheet do admin sobre um participante usa `groupMemberViewProfile` (Ver perfil), e o voltar das confirmações, `commonBack`.
- "Avisado" nas frases acima é a notificação gravada no histórico (RN110). O push chega na fatia 7.

### 8.5 Admins do jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `gameAdmins` | Admins do jogo | Opção do menu e título da tela |
| `gameAdminOnList` | Na lista | Subtítulo da linha |
| `gameAdminOffList` | Fora da lista | Subtítulo da linha (RN26) |
| `gameAdminAdd` | Adicionar admin | Botão principal |
| `gameAdminAddSheetTitle` | Quem vai ser admin? | Título da sheet |
| `gameAdminsNoCandidates` | Só quem está na lista pode ser admin, e todos da lista já são. | Frase da sheet sem ninguém para adicionar (RN27) |
| `gameAdminRemove` | Remover admin | Opção da sheet |
| `gameAdminAdded` | {name} agora é admin do jogo. | `SnackBar` |
| `gameAdminRemoved` | {name} não é mais admin do jogo. | `SnackBar` |
| `gameAdminStepDown` | Deixar de ser admin | Opção da sheet e botão da confirmação |
| `gameAdminStepDownTitle` | Deixar de ser admin do jogo? | Título da confirmação |
| `gameAdminStepDownBody` | Só outro admin do jogo poderá devolver esse papel a você. | Frase da confirmação |
| `gameAdminSteppedDown` | Você não é mais admin deste jogo. | `SnackBar` |

### 8.6 Jogos no grupo e saída do grupo

| Chave | Texto | Onde |
|-------|-------|------|
| `groupGamesTitle` | Próximos jogos | Título da seção no detalhe do grupo |
| `groupGamesEmpty` | Nenhum jogo marcado neste grupo. | Frase da seção vazia |
| `groupLeaveGamesBody` | Você também sai da lista e da espera dos jogos do grupo que ainda não começaram, sem multa. | Segunda frase da confirmação de saída (RN14) |
| `groupLeftWithGames` | Você saiu do grupo e de 1 jogo. / Você saiu do grupo e de {count} jogos. | `SnackBar` (plural) |
| `groupMemberRemoveGamesBody` | {name} também sai da lista e da espera dos jogos do grupo que ainda não começaram, sem multa. | Segunda frase da confirmação de remoção |
| `groupMemberRemovedWithGames` | Removemos {name} do grupo e de 1 jogo. / Removemos {name} do grupo e de {count} jogos. | `SnackBar` (plural) |
| `groupLeaveBlockedTitle` | Você ainda não pode sair do grupo | Título da sheet de bloqueio |
| `groupRemoveBlockedTitle` | Ainda não dá para remover {name} | Título da sheet de bloqueio na remoção |
| `groupBlockedReceiverBody` | Você é o recebedor destes jogos, que ainda não foram concluídos. Para sair do grupo, um admin de cada jogo precisa indicar outro recebedor, ou o jogo precisa ser cancelado ou concluído. | Frase da sheet, `MEMBER_IS_RECEIVER`. Texto da fatia 5 |
| `groupBlockedOnlyAdminBody` | Você é o único admin destes jogos. Indique outro admin em Admins do jogo antes de sair. | Frase da sheet, `MEMBER_IS_ONLY_GAME_ADMIN` |
| `groupRemoveBlockedReceiverBody` | {name} é o recebedor destes jogos, que ainda não foram concluídos. Para remover, um admin de cada jogo precisa indicar outro recebedor, ou o jogo precisa ser cancelado ou concluído. | Frase da sheet na remoção. Texto da fatia 5 |
| `groupRemoveBlockedOnlyAdminBody` | {name} é o único admin destes jogos. Peça a {name} para indicar outro admin neles. | Frase da sheet na remoção (RN15: o admin do grupo não indica admin do jogo) |

- A sheet usa `commonBack` no botão de contorno.

### 8.7 Perfil de outra pessoa, telefone

| Chave | Texto | Onde |
|-------|-------|------|
| `personPhone` | Telefone | Rótulo da linha |
| `personCall` | Ligar | Botão de contorno |
| `personWhatsapp` | WhatsApp | Botão de contorno |
| `commonCannotOpenLink` | Não foi possível abrir neste aparelho. | `SnackBar` quando o Maps, o discador ou o WhatsApp não abrem |

**Formato do telefone** (`formatPhone`, em `app/lib/core/format/`): sem o `+55`, com o DDD entre parênteses e o hífen antes dos 4 últimos dígitos: `(86) 99999-8888` com 11 dígitos e `(86) 3322-4455` com 10 (U12).

### 8.8 Erros

Códigos das funções de jogo e da RN16 (`contratos-api.md`, seção 2). O texto final é este, e não a mensagem inicial do contrato. `GAME_CANCELLED` e `GAME_NOT_ENDED` entram na fatia 5.

| Código | `ErrorCode` | Chave | Texto |
|--------|-------------|-------|-------|
| `NOT_GAME_ADMIN` | `notGameAdmin` | `errorNotGameAdmin` | Só um admin do jogo pode fazer isso. |
| `INVALID_GAME_DATES` | `invalidGameDates` | `errorInvalidGameDates` | O prazo não pode passar do início, e o início precisa ser antes do fim. |
| `START_IN_PAST` | `startInPast` | `errorStartInPast` | O início precisa estar no futuro. |
| `RECEIVER_NEEDS_PIX_KEY` | `receiverNeedsPixKey` | `errorReceiverNeedsPixKey` | O recebedor precisa ter uma chave Pix. |
| `NO_GAME_ACCESS` | `noGameAccess` | `errorNoGameAccess` | Para entrar neste jogo, você precisa ser membro do grupo ou ter o convite. |
| `GAME_NOT_OPEN` | `gameNotOpen` | `errorGameNotOpen` | Este jogo já foi cancelado ou concluído. |
| `GAME_FULL` | `gameFull` | `errorGameFull` | A lista encheu. Você pode entrar na lista de espera. |
| `GAME_NOT_FULL` | `gameNotFull` | `errorGameNotFull` | Abriu uma vaga. Você pode entrar direto na lista. |
| `GAME_STARTED` | `gameStarted` | `errorGameStarted` | O jogo já começou. |
| `LIST_LOCKED` | `listLocked` | `errorListLocked` | A lista está travada até a conclusão do jogo. |
| `ALREADY_PARTICIPANT` | `alreadyParticipant` | `errorAlreadyParticipant` | Você já está na lista. |
| `ALREADY_ON_WAITLIST` | `alreadyOnWaitlist` | `errorAlreadyOnWaitlist` | Você já está na lista de espera. |
| `NOT_ON_WAITLIST` | `notOnWaitlist` | `errorNotOnWaitlist` | Você não está na lista de espera. |
| `NOT_PARTICIPANT` | `notParticipant` | `errorNotParticipant` | Esta pessoa não está mais na lista. |
| `RECEIVER_LOCKED` | `receiverLocked` | `errorReceiverLocked` | O recebedor não pode sair da lista. |
| `SLOT_LIMIT_BELOW_PARTICIPANTS` | `slotLimitBelowParticipants` | `errorSlotLimitBelowParticipants` | O limite não pode ficar abaixo do número de pessoas na lista. |
| `ADMIN_MUST_BE_PARTICIPANT` | `adminMustBeParticipant` | `errorAdminMustBeParticipant` | Só quem está na lista pode ser admin do jogo. |
| `ALREADY_GAME_ADMIN` | `alreadyGameAdmin` | `errorAlreadyGameAdmin` | Esta pessoa já é admin do jogo. |
| `NOT_GAME_ADMIN_TARGET` | `notGameAdminTarget` | `errorNotGameAdminTarget` | Esta pessoa não é mais admin do jogo. |
| `LAST_GAME_ADMIN` | `lastGameAdmin` | `errorLastGameAdmin` | Indique outro admin antes. O jogo precisa de ao menos um. |
| `MEMBER_IS_RECEIVER` | `memberIsReceiver` | `errorMemberIsReceiver` | Há jogos em aberto deste grupo com esta pessoa como recebedora. |
| `MEMBER_IS_ONLY_GAME_ADMIN` | `memberIsOnlyGameAdmin` | `errorMemberIsOnlyGameAdmin` | Há jogos em aberto deste grupo com esta pessoa como única admin. |

- `MEMBER_IS_RECEIVER` e `MEMBER_IS_ONLY_GAME_ADMIN` normalmente abrem a sheet de bloqueio (`docs/ui/telas.md`, 7.8). O texto da tabela é a reserva, para quando a leitura dos jogos de `detail.game_ids` falhar.
- `CANNOT_REMOVE_SELF` (fatia 3) também é devolvido por `remove_participant`. A tela do jogo nunca oferece remover a si mesmo (`docs/ui/telas.md`, 7.3), então o texto de grupo continua valendo.
- O `ErrorCode` passa a guardar o `detail` do erro quando ele traz `game_ids`, para a sheet de bloqueio (E16).

## 9. Fatia 5

Decisões de 18/11/2026. Telas em `docs/ui/telas.md`, seção 8. Palavras do domínio: **concluir** (o jogo), **rateio**, **parte por vaga**, **valor a pagar**, **multa**, **falta**, **isentar**, **recebedor**, **por conta de** (o valor que o recebedor cobre, RN74). Os textos provisórios da seção 5.2 saem do ARB nesta fatia, com a aba Cobranças real.

### 9.1 Detalhe do jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `gameComplete` | Concluir jogo | Botão do pé, opção do menu do admin, título e botão principal da conclusão |
| `gameCompleteHint` | Se ninguém concluir, o app conclui sozinho 1 hora depois do fim. | Frase acima do botão do pé (RN45) |
| `gameSharePerSlot` | Parte por vaga | Rótulo do trio e do resumo |
| `gameTotal` | Total | Rótulo do trio |
| `gameTrioAtStart` | no início | Legenda de Vagas no trio do concluído (decisão de 18/11/2026, sessão 3, pelo PNG) |
| `gameTrioFinal` | final | Legenda de Parte por vaga no trio do concluído |
| `gameTrioVenue` | do espaço | Legenda de Total no trio do concluído e do Rateio |
| `gameAbsentBadge` | Faltou | Selo `bad` da lista do jogo concluído |
| `gameChangeReceiver` | Trocar recebedor | Opção do menu do admin e título da sheet |
| `splitCardTitle` | Rateio | Título do card do detalhe e da tela |
| `historyTitle` | Sua participação | Título do card |
| `historyCancelledOnTime` | Saiu {date} às {time}, no prazo | Linha do card |
| `historyCancelledLate` | Saiu {date} às {time}, fora do prazo | Linha do card |
| `historyVoided` | Não conta: você voltou às {time} | Linha de apoio (RN56) |
| `historyExempt` | Multa isentada: sobraram vagas | Linha de apoio e linha do rateio (RN62) |
| `historyLeftAfterStart` | Saiu às {time}, depois do início | Linha do card |
| `historyRemovedByAdmin` | Removido por um admin em {date} | Linha do card |
| `historyRemovedGroupLeft` | Saiu do grupo em {date} | Linha do card |
| `historyMarkedAbsent` | Falta marcada na conclusão | Linha do card |
| `historyAbsentLeft` | Falta pela saída depois do início | Linha do card |

`{date}` usa `formatShortDate` e `{time}`, `formatTime`.

### 9.2 Concluir jogo

| Chave | Texto | Onde |
|-------|-------|------|
| `completeTotalHint` | Só dá para mudar agora. Depois da conclusão, nada é recalculado. | Dica do campo de valor total (RN34, RN36) |
| `completeAbsentTitle` | Quem faltou? | Título da seção de faltas |
| `completeLeftAt` | Saiu às {time} | Linha de apoio de quem saiu depois do início |
| `completeAbsentLabel` | Marcar falta de {name} | Rótulo de acessibilidade da caixa |
| `completeReceiverNoAbsence` | O recebedor não leva falta. | Frase abaixo da lista (RF63) |
| `completeSummaryTitle` | Rateio | Título do resumo |
| `completeToReceive` | A receber | Linha do resumo |
| `completeShareFormula` | {total} ÷ {slots} vagas | Legenda da parte por vaga no resumo (pelo PNG) |
| `splitReceiverCovers` | Por conta de {name} | Rótulo do valor por conta do recebedor (RN74), no resumo e no rateio |
| `splitReceiverExtra` | {name} recebe {amount} a mais que o total, pelo arredondamento. | No lugar do valor quando o por conta é negativo (R04) |
| `completeExemptedCount` | 1 multa de cancelamento isentada: sobraram vagas. / {count} multas de cancelamento isentadas: sobraram vagas. | Linha do resumo (plural) |
| `completeUncoveredWarning` | 1 vaga ficou sem ninguém. {amount} fica por conta de {name}. / {count} vagas ficaram sem ninguém. {amount} fica por conta de {name}. | Aviso em linha (RF41, plural) |
| `completeConfirmTitle` | Concluir o jogo? | Título da confirmação |
| `completeConfirmBody` | A conclusão é definitiva: depois dela, o valor total e as faltas não mudam, e cada pessoa passa a ter o valor a pagar. | Frase da confirmação (RN36) |
| `completeConfirmAction` | Concluir | Botão da confirmação |
| `gameCompleted` | Jogo concluído. | `SnackBar` |

### 9.3 Rateio

| Chave | Texto | Onde |
|-------|-------|------|
| `splitYourValue` | Seu valor | Título do bloco |
| `splitOwedTo` | Para {name} | Linha de apoio do valor (RN32) |
| `splitNoCharge` | Você não tem valor a pagar neste jogo. | Bloco sem valor e card do detalhe |
| `splitNoChargeReceiver` | Você é o recebedor. Fica por conta sua {amount}. | Motivo |
| `splitNoChargeOnTime` | Você saiu no prazo, sem multa. | Motivo (RN60) |
| `splitNoChargeExempt` | Sua multa foi isentada: sobraram vagas. | Motivo (RN62) |
| `splitNoChargeRemoved` | Você saiu da lista sem multa. | Motivo (RN58, RN14) |
| `splitReceived` | Recebido | Total do recebedor e dos admins |
| `splitPending` | Pendente | Total do recebedor e dos admins |
| `splitCharges` | Valores | Título da lista |
| `splitWaived` | Isentos | Título da lista |
| `splitNoChargeSection` | Sem valor a pagar | Título da lista |
| `splitTrioLimit` | limite | Legenda de Vagas no trio do Rateio (pelo PNG) |
| `splitShareFormula` | {total} ÷ {slots} | Legenda de Parte por vaga no trio do Rateio (pelo PNG) |
| `chargeKindShare` | Parte do jogo | Rótulo do `kind` |
| `chargeKindAbsence` | Multa por falta | Rótulo do `kind` |
| `chargeKindLateCancellation` | Multa por cancelamento | Rótulo do `kind` |
| `chargeWaivedManual` | Isentado por um admin | Motivo do Isento (RN93) |
| `chargeWaivedReceiverChange` | Anulado na troca de recebedor | Motivo do Isento (RN94) |
| `waiveAction` | Isentar multa | Opção da sheet e botão da confirmação |
| `waiveActionHint` | O valor deixa de ser cobrado | Linha de apoio da opção (decisão de 18/11/2026, sessão 3 da etapa B, pelo PNG) |
| `waiveTitle` | Isentar a multa de {name}? | Título da confirmação |
| `waiveBody` | O valor deixa de ser cobrado e não pode voltar. | Frase da confirmação |
| `penaltyWaived` | Multa isentada. | `SnackBar` |
| `chargeStatusPending` | Pendente | Selo `warn` (`design-system.md`, seção 4) |
| `chargeStatusUnderReview` | Em análise | Selo `info` |
| `chargeStatusPaid` | Pago | Selo `ok` |
| `chargeStatusWaived` | Isento | Selo `neutral` |

### 9.4 Trocar recebedor

| Chave | Texto | Onde |
|-------|-------|------|
| `receiverChangeBeforeBody` | O novo recebedor precisa estar na lista e ter uma chave Pix. Os valores do jogo serão devidos a ele. | Explicação antes da conclusão (RN30) |
| `receiverChangeAfterBody` | Os valores já pagos continuam com o recebedor atual, e os pendentes passam ao novo. O valor do novo recebedor é anulado, e o recebedor atual passa a pagar a parte dele. O acerto do que já foi pago fica entre os dois, fora do app. | Explicação depois da conclusão (RN31) |
| `receiverChangeEmpty` | Ninguém mais na lista pode ser o recebedor. | Sem candidatos |
| `receiverChangeConfirmTitle` | Trocar o recebedor para {name}? | Título da confirmação |
| `receiverChangeConfirmAction` | Trocar | Botão da confirmação |
| `receiverChanged` | {name} agora é o recebedor. | `SnackBar` |

### 9.5 Cobranças

| Chave | Texto | Onde |
|-------|-------|------|
| `chargesTitle` | Cobranças | Título da aba |
| `chargesToPay` | A pagar | Atalho e título da seção |
| `chargesToReceive` | A receber | Atalho e título da seção |
| `chargesToPayGames` | em 1 jogo / em {count} jogos | Linha do atalho (plural) |
| `chargesToReceivePeople` | de 1 pessoa / de {count} pessoas | Linha do atalho (plural) |
| `chargesPeopleCount` | 1 pessoa / {count} pessoas | Linha de apoio da seção A receber (plural) |
| `chargesNothingToPay` | Você não deve nada. | Seção vazia |
| `chargesNothingToReceive` | Ninguém te deve. | Seção vazia |
| `chargesEmptyTitle` | Tudo certo por aqui | Estado vazio da aba |
| `chargesEmptyBody` | Quando um jogo for concluído, os valores aparecem aqui. | Estado vazio da aba |
| `chargesTabBadgeLabel` | 1 valor a pagar / {count} valores a pagar | Rótulo de acessibilidade do contador da aba (plural) |

### 9.6 Erros

Códigos das funções da fatia 5 (`contratos-api.md`, seção 2). Entram também os dois que a seção 8.8 deixou para esta fatia.

| Código | `ErrorCode` | Chave | Texto |
|--------|-------------|-------|-------|
| `GAME_CANCELLED` | `gameCancelled` | `errorGameCancelled` | Este jogo foi cancelado. |
| `GAME_NOT_ENDED` | `gameNotEnded` | `errorGameNotEnded` | O jogo só pode ser concluído a partir do horário de fim. |
| `ABSENT_NOT_PARTICIPANT` | `absentNotParticipant` | `errorAbsentNotParticipant` | A lista mudou. Confira as faltas de novo. |
| `RECEIVER_CANNOT_BE_ABSENT` | `receiverCannotBeAbsent` | `errorReceiverCannotBeAbsent` | O recebedor não pode ser marcado como faltoso. |
| `RECEIVER_MUST_BE_PARTICIPANT` | `receiverMustBeParticipant` | `errorReceiverMustBeParticipant` | O novo recebedor precisa estar na lista. |
| `RECEIVER_UNCHANGED` | `receiverUnchanged` | `errorReceiverUnchanged` | Esta pessoa já é a recebedora do jogo. |
| `RECEIVER_CHANGE_BLOCKED` | `receiverChangeBlocked` | `errorReceiverChangeBlocked` | Há valores Em análise. Decida-os antes de trocar o recebedor. |
| `NOT_A_PENALTY` | `notAPenalty` | `errorNotAPenalty` | Só multas podem ser isentadas. |
| `CHARGE_NOT_PENDING` | `chargeNotPending` | `errorChargeNotPending` | Este valor não está mais Pendente. |

- Na fatia 5, `RECEIVER_CHANGE_BLOCKED` só acontece com dado inserido direto, porque Em análise chega na fatia 6. O texto já fica pronto.
