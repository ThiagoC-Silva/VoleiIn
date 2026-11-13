# VoleiIn: telas de conta e perfil

## Sobre o app

O VoleiIn é um app Android, em português do Brasil, para grupos de vôlei. Ele organiza jogos e listas de presença, calcula a divisão do valor da quadra e acompanha os pagamentos por Pix entre os participantes. O app não processa pagamentos.

Este documento descreve as telas de **acesso** (login, cadastro, confirmação de e-mail, recuperação de senha, aceite dos termos) e de **perfil** (ver e editar os dados, chave Pix, trocar e-mail e senha).

## Regras gerais

- **Celular Android, só modo escuro.** Largura de referência: 360 dp.
- **Tom dos textos:** informal, curto, tratando por "você". Sem termos técnicos e sem exclamação em mensagens de erro. Os botões usam verbo no infinitivo ("Entrar", "Salvar").
- **Textos:** os que aparecem entre aspas ou em negrito neste documento são os textos finais da tela.
- **Acessibilidade:** toda área de toque tem pelo menos 48 × 48 dp. As telas precisam funcionar com a fonte do sistema em 150%, sem nada cortado ou sobreposto, e rolam quando o teclado abre. Erro nunca é indicado só pela cor: o campo com erro mostra ícone e mensagem abaixo.
- **Um botão principal por tela.** As outras ações são botões de contorno ou de texto.
- **Tipos de botão:**
  - principal: preenchido, com a cor de destaque;
  - contorno: só a borda;
  - texto: sem fundo, parece um link;
  - destrutivo de contorno: borda neutra e texto avermelhado;
  - destrutivo sólido: fundo vermelho, usado só na confirmação final de algo destrutivo.
- **Estados comuns**, que valem para todas as telas:
  - **Enviando:** o botão principal troca o texto por um indicador de progresso e bloqueia novo toque, e os campos ficam desabilitados.
  - **Erro de uma ação:** aparece uma mensagem flutuante na parte de baixo da tela (*snackbar*), e a tela continua como estava, com o que foi digitado.
  - **Erro de um campo:** a borda fica com a cor de erro, com um ícone e a mensagem abaixo do campo.
  - **Carregando dados:** indicador circular no centro.
  - **Falha ao carregar ou sem internet:** ícone, uma frase e o botão **Tentar de novo**, no lugar do conteúdo.
- **Rótulo dos campos** acima do campo, fora dele.
- **Campo de senha:** texto oculto, com um botão de olho à direita para mostrar e ocultar.
- **Campo de código:** 6 dígitos, teclado numérico. Confirma sozinho ao completar o sexto dígito, sem precisar tocar no botão. A forma é livre: um campo só ou seis casas.
- **Reenviar código:** botão de texto. Depois de cada envio, fica desabilitado por 60 segundos, com a contagem no próprio rótulo: "Reenviar código em 45 s". Depois volta a ser "Reenviar código".
- **Barra superior interna:** botão circular de voltar à esquerda e o título da tela.
- **Barra inferior:** quatro abas, nesta ordem: **Jogos**, **Grupos**, **Cobranças** e **Perfil**. Aparece só nas telas de perfil indicadas abaixo. As telas de acesso e as de edição cobrem a barra.

## Fluxo entre as telas

1. **Sem login**, o app abre no **Login**.
2. No Login, a pessoa pode:
   - entrar com e-mail e senha;
   - tocar em **Continuar com Google**;
   - ir ao **Cadastro**;
   - ir a **Recuperar senha**.
3. O **Cadastro** leva à **Confirmação do e-mail**, onde a pessoa digita o código enviado por e-mail. Depois do código, ela já está logada.
4. **Logo depois do primeiro acesso**, seja pelo cadastro, pelo login ou pelo Google, a pessoa passa pelo **Aceite dos termos**. Essa tela aparece de novo quando os Termos ou a Política mudam de versão.
5. Depois do aceite, o app abre na aba **Jogos**. A aba **Perfil** leva às telas de perfil.
6. **Sair**, na aba Perfil, volta ao Login.

---

## 1. Login

**Objetivo:** entrar no app.

**Conteúdo, de cima para baixo:**

1. Espaço do logo: por enquanto, o texto **VoleiIn** em destaque.
2. Subtítulo: "Entre para ver seus jogos."
3. Campo **E-mail**: teclado de e-mail, sem correção automática.
4. Campo **Senha**, com o olho.
5. Botão de texto **Esqueci minha senha**, alinhado à direita, logo abaixo da senha.
6. Botão principal **Entrar**.
7. Divisor com a palavra **ou** no meio.
8. Botão de contorno **Continuar com Google**. Ele entra na conta e também cria a conta de quem ainda não tem.
9. No pé da tela: "Não tem conta?" seguido do botão de texto **Criar conta**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| E-mail ou senha vazios ao tocar em Entrar | Erro no campo: "Informe o seu e-mail." ou "Informe a sua senha." |
| E-mail ou senha errados | *Snackbar*: "E-mail ou senha incorretos." |
| E-mail ainda não confirmado | *Snackbar*: "Confirme o seu e-mail antes de entrar.", com a ação **Confirmar**, que envia um código novo e abre a Confirmação do e-mail |
| Muitas tentativas | *Snackbar*: "Muitas tentativas. Espere alguns minutos e tente de novo." |
| Sem internet | *Snackbar*: "Sem conexão com a internet. Confira a sua rede e tente de novo." |
| Toca em Continuar com Google | Abre o seletor de contas do Google. Entrar e Continuar com Google ficam bloqueados até o fim |
| Fecha o seletor do Google sem escolher | Nada acontece |
| Falha no Google | *Snackbar*: "Não foi possível entrar com o Google. Tente de novo." |

---

## 2. Cadastro

**Objetivo:** criar a conta com nome, e-mail e senha.

**Conteúdo:**

1. Barra superior interna com o título **Criar conta**.
2. Frase de apoio: "Crie sua conta para entrar nas listas dos seus grupos."
3. Campo **Nome**.
4. Campo **E-mail**.
5. Campo **Senha**, com o olho e a dica abaixo: "Pelo menos 8 caracteres".
6. Botão principal **Criar conta**.
7. No pé: "Já tem conta?" seguido do botão de texto **Entrar**, que volta ao Login.

Não há caixa de aceite dos termos nesta tela: o aceite vem depois, numa tela própria.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nome vazio | "Informe o seu nome." |
| Nome com mais de 80 caracteres | "O nome pode ter até 80 caracteres." |
| E-mail vazio | "Informe o seu e-mail." |
| Senha vazia | "Informe a sua senha." |
| Senha com menos de 8 caracteres | "A senha precisa ter pelo menos 8 caracteres." |
| E-mail inválido | *Snackbar*: "Confira o e-mail informado." |
| Sucesso | Abre a Confirmação do e-mail. O voltar não retorna ao Cadastro |

---

## 3. Confirmação do e-mail

**Objetivo:** digitar o código de 6 dígitos que chegou por e-mail.

**Conteúdo:**

1. Título: **Confirme o seu e-mail**.
2. Frase com o e-mail: "Enviamos um código de 6 dígitos para ana@exemplo.com."
3. Campo de código.
4. Botão principal **Confirmar**.
5. Botão de texto **Reenviar código**, com a contagem de 60 segundos.
6. Frase de ajuda, em tom secundário: "Não chegou? Confira o spam. Se este e-mail já tem conta, entre ou recupere a senha."
7. Botão de texto **Usar outro e-mail**, que volta ao Cadastro com os campos preenchidos.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Código completo | Confirma. A pessoa fica logada e segue para o Aceite dos termos |
| Código errado ou vencido | Erro no campo: "Código incorreto ou vencido. Confira ou peça um novo." O campo é limpo |
| Reenviar código | *Snackbar*: "Enviamos um novo código." |
| Muitos e-mails pedidos | *Snackbar*: "Muitos e-mails enviados. Espere alguns minutos e tente de novo." |

---

## 4. Recuperar senha

**Objetivo:** criar uma senha nova com um código enviado ao e-mail. A tela tem **duas etapas**, sem trocar de tela.

**Barra superior interna** com o título **Recuperar senha**. Na etapa 2, o voltar leva de volta à etapa 1.

**Etapa 1:**

1. Frase: "Informe o e-mail da sua conta. Vamos enviar um código para criar uma senha nova."
2. Campo **E-mail**, já preenchido se a pessoa digitou o e-mail no Login.
3. Botão principal **Enviar código**.

O app sempre avança para a etapa 2, exista ou não conta com aquele e-mail.

**Etapa 2:**

1. Frase com o e-mail: "Enviamos um código de 6 dígitos para ana@exemplo.com."
2. Campo de código.
3. Campo **Nova senha**, com o olho.
4. Botão principal **Salvar nova senha**.
5. Botão de texto **Reenviar código**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nova senha com menos de 8 caracteres | "A senha precisa ter pelo menos 8 caracteres." |
| Código errado ou vencido | Erro no campo de código: "Código incorreto ou vencido. Confira ou peça um novo." |
| Nova senha igual à antiga | Erro no campo de senha: "A nova senha precisa ser diferente da atual." Aqui o código já foi aceito, então a tela passa a mostrar só o campo de senha e o botão |
| Sucesso | *Snackbar*: "Senha alterada." A pessoa entra no app |

---

## 5. Aceite dos termos

**Objetivo:** aceitar os Termos de Uso e a Política de Privacidade. Aparece logo depois do primeiro acesso e de novo sempre que algum dos dois documentos muda de versão.

**Sem barra inferior e sem botão de voltar.** O voltar do Android fecha o app.

**Conteúdo:**

1. Título: **Antes de continuar**.
2. Frase de apoio:
   - no primeiro aceite: "Para usar o VoleiIn, leia e aceite os documentos abaixo.";
   - quando a versão mudou: "Atualizamos os documentos abaixo. Leia e aceite para continuar."
3. Duas linhas tocáveis, com uma seta à direita:
   - **Termos de Uso**, com o subtítulo "Versão 1.0";
   - **Política de Privacidade**, com o subtítulo "Versão 1.0".

   Cada linha abre o texto do documento.
4. Caixa de seleção, desmarcada: "Li e aceito os Termos de Uso e a Política de Privacidade".
5. Botão principal **Aceitar e continuar**, desabilitado até a caixa ser marcada.
6. Botão de texto **Sair**, que volta ao Login.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Aceitar e continuar | Abre a aba Jogos |
| Erro ou sem internet | *Snackbar*. A caixa continua marcada |
| Fecha o app sem aceitar | Na próxima abertura, volta a esta tela |

---

## 6. Texto de um documento

**Objetivo:** ler os Termos de Uso ou a Política de Privacidade.

**Conteúdo:**

- Barra superior interna, com o nome do documento como título.
- Corpo de texto que rola.
- Por enquanto, só uma frase provisória: "O texto definitivo deste documento chega antes do lançamento do app."

---

## 7. Meu perfil

**Objetivo:** ver os próprios dados e chegar às edições. É a tela da aba **Perfil**: **a barra inferior aparece**, com Perfil ativo.

**Conteúdo, de cima para baixo:**

1. Barra superior de tela principal, com o título **Perfil** grande, sem botão de voltar.
2. Cabeçalho:
   - avatar circular de 72 dp: a foto da pessoa ou, sem foto, as iniciais sobre um fundo pastel;
   - o nome exibido, que é o apelido se houver ou, senão, o nome;
   - abaixo, o e-mail da conta, em tom secundário.
3. Lista de linhas tocáveis, cada uma com uma seta à direita:
   - **Editar perfil**, com o subtítulo "Nome, apelido, foto e telefone";
   - **Chave Pix**, com o subtítulo "CPF · 529.982.247-25" (tipo e chave) ou "Não cadastrada";
   - **Trocar e-mail**;
   - **Trocar senha**.
4. Botão de contorno **Sair**, sem pedido de confirmação.

**Variante: conta que entrou só pelo Google.** A mesma tela, **sem** as linhas Trocar e-mail e Trocar senha.

---

## 8. Editar perfil

**Objetivo:** editar nome, apelido, foto e telefone. Tudo é gravado junto, no botão Salvar.

**Conteúdo:**

1. Barra superior interna com o título **Editar perfil**.
2. Avatar circular de 96 dp com o botão de texto **Trocar foto**. A foto escolhida aparece no avatar antes de salvar.
3. Campo **Nome**.
4. Campo **Apelido**, opcional, com a dica: "Aparece no lugar do nome nas listas".
5. Campo **Telefone**, opcional:
   - o prefixo **+55** fica fixo à esquerda;
   - a pessoa digita DDD e número, com a máscara `(86) 99999-1234`.
6. Interruptor **Mostrar meu telefone**, com a dica: "Quem estiver nos seus grupos e jogos poderá ver".
   - Desligado por padrão.
   - Desabilitado enquanto o telefone está vazio.
   - Apagar o telefone desliga o interruptor.
7. Botão principal **Salvar**.

**Folha da foto**, que abre de baixo ao tocar em Trocar foto: as opções **Escolher da galeria**, **Tirar foto** e, se já houver foto, **Remover foto**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nome vazio ou com mais de 80 caracteres | "Informe o seu nome." / "O nome pode ter até 80 caracteres." |
| Apelido com mais de 30 caracteres | "O apelido pode ter até 30 caracteres." |
| Telefone incompleto | "Informe o DDD e o número, com 10 ou 11 dígitos." |
| Foto acima de 2 MB | *Snackbar*: "A foto passa de 2 MB. Escolha outra." |
| Foto que não é JPEG, PNG ou WebP | *Snackbar*: "Use uma foto JPEG, PNG ou WebP." |
| Sucesso | *Snackbar*: "Perfil salvo." Volta ao Meu perfil |
| Voltar sem salvar | As alterações são descartadas, sem pedido de confirmação |

---

## 9. Chave Pix

**Objetivo:** cadastrar, trocar e remover a chave Pix, que outras pessoas usam para pagar quando esta pessoa recebe pelo jogo.

**Conteúdo:**

1. Barra superior interna com o título **Chave Pix**.
2. Rótulo **Tipo da chave** e cinco opções, uma escolhida por vez: **CPF**, **CNPJ**, **E-mail**, **Telefone** e **Aleatória**. Trocar o tipo limpa o campo.
3. Campo **Chave**, com teclado e máscara conforme o tipo:

   | Tipo | Teclado | Máscara ou formato |
   |------|---------|--------------------|
   | CPF | Numérico | `000.000.000-00` |
   | CNPJ | Numérico | `00.000.000/0000-00` |
   | E-mail | E-mail | Livre |
   | Telefone | Numérico | `+55` fixo e `(86) 99999-1234` |
   | Aleatória | Texto | Código longo com hífens, colado do banco |

4. Botão principal **Salvar**.
5. Se já houver chave, o botão destrutivo de contorno **Remover chave**.

**Confirmação de remoção**, uma folha que abre de baixo:

- título: **Remover a chave Pix?**;
- frase: "Sem chave Pix, você não pode ser recebedor de jogos.";
- botão destrutivo sólido **Remover**;
- botão de contorno **Voltar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| CPF inválido (os dígitos verificadores não conferem) | "CPF inválido. Confira os números." |
| CNPJ inválido | "CNPJ inválido. Confira os números." |
| E-mail inválido | "E-mail inválido." |
| Telefone incompleto | "Informe o DDD e o número, com 10 ou 11 dígitos." |
| Chave aleatória inválida | "Chave aleatória inválida. Copie e cole a chave do seu banco." |
| Salvar com sucesso | *Snackbar*: "Chave Pix salva." Volta ao Meu perfil |
| Remoção recusada (a pessoa recebe por um jogo em aberto ou tem valores a receber) | *Snackbar*: "Você pode trocar a chave, mas não removê-la enquanto tiver jogos em aberto ou valores a receber." A chave continua |

---

## 10. Trocar e-mail

**Objetivo:** trocar o e-mail de acesso, com um código enviado ao novo endereço. A tela tem **duas etapas**, sem trocar de tela. Só existe para quem tem login por e-mail e senha.

**Barra superior interna** com o título **Trocar e-mail**.

**Etapa 1:**

1. Texto: "E-mail atual: ana@exemplo.com"
2. Campo **Novo e-mail**.
3. Frase: "Até você digitar o código, o e-mail atual continua valendo."
4. Botão principal **Enviar código**.

**Etapa 2:**

1. Frase com o novo e-mail: "Enviamos um código de 6 dígitos para novo@exemplo.com."
2. Campo de código.
3. Botão principal **Confirmar**.
4. Botão de texto **Reenviar código**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Novo e-mail igual ao atual | "Este já é o seu e-mail." |
| E-mail que já é de outra conta | "Este e-mail já é usado por outra conta." |
| Código errado ou vencido | "Código incorreto ou vencido. Confira ou peça um novo." |
| Sucesso | *Snackbar*: "E-mail alterado." Volta ao Meu perfil, que já mostra o novo e-mail |

---

## 11. Trocar senha

**Objetivo:** trocar a senha, informando a atual. Só existe para quem tem login por e-mail e senha.

**Conteúdo:**

1. Barra superior interna com o título **Trocar senha**.
2. Campo **Senha atual**, com o olho.
3. Campo **Nova senha**, com o olho.
4. Botão principal **Salvar**.

**Comportamento:**

| Situação | O que acontece |
|----------|----------------|
| Nova senha com menos de 8 caracteres | "A senha precisa ter pelo menos 8 caracteres." |
| Senha atual errada | Erro no campo Senha atual: "Senha atual incorreta." |
| Nova senha igual à atual | Erro no campo Nova senha: "A nova senha precisa ser diferente da atual." |
| Sucesso | *Snackbar*: "Senha alterada." Volta ao Meu perfil |

---

## Imagens a produzir

Uma imagem por tela ou variante, com estes nomes:

| Arquivo | Tela |
|---------|------|
| `login.png` | 1. Login |
| `signup.png` | 2. Cadastro |
| `confirmEmail.png` | 3. Confirmação do e-mail |
| `forgotPassword-etapa1.png` | 4. Recuperar senha, etapa 1 |
| `forgotPassword-etapa2.png` | 4. Recuperar senha, etapa 2 |
| `terms.png` | 5. Aceite dos termos |
| `termsDocument.png` | 6. Texto de um documento (opcional) |
| `profile.png` | 7. Meu perfil, com e-mail e senha |
| `profile-google.png` | 7. Meu perfil, conta só com Google |
| `profileEdit.png` | 8. Editar perfil |
| `profileEdit-foto.png` | 8. Folha da foto |
| `profilePix.png` | 9. Chave Pix |
| `profilePix-remover.png` | 9. Confirmação de remoção |
| `profileEmail-etapa1.png` | 10. Trocar e-mail, etapa 1 |
| `profileEmail-etapa2.png` | 10. Trocar e-mail, etapa 2 |
| `profilePassword.png` | 11. Trocar senha |

Não é preciso desenhar os estados comuns (carregando, erro, sem internet, *snackbar*, erro de campo), salvo se quiser uma aparência diferente do padrão descrito em "Regras gerais".
