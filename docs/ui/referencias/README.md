# Referências visuais das telas

> Decisão de 12/11/2026. Nenhuma tela é implementada sem o PNG de referência do responsável.
> Fluxo: o agente escreve aqui o **briefing** de cada tela da fatia (o que ela precisa conter); o responsável desenha e salva o PNG nesta pasta; só então a tela entra no código.

## Como funciona

- **Pasta e nome:** `docs/ui/referencias/fatia-<n>/<nomeDaRota>.png`, com o nome da rota de `docs/ui/telas.md` (seção 1). Variantes e etapas levam um sufixo: `forgotPassword-etapa2.png`, `profile-google.png`.
- **Quem decide o quê:** o PNG decide a **aparência e a disposição**. O `telas.md` decide **o que a tela contém e como se comporta**, e o `docs/copy.md` decide os textos. Se o PNG não tiver um elemento do briefing, ou tiver um a mais, o agente para e pergunta antes de implementar.
- **O que não precisa desenhar:** os estados comuns já definidos no `design-system.md` (carregando, erro, sem conexão, erro no campo, `SnackBar`, botão carregando, seções 7.1, 7.2 e 7.16). Desenhe só se quiser algo diferente do padrão.
- **Base visual:** só modo escuro, cores, fontes e componentes do `design-system.md` (ADR 0013). Largura de referência: 360 dp (celular comum). Os textos do PNG podem ser aproximados: o texto final vem do `docs/copy.md`.
- **Obrigatório** no briefing: sem esse PNG, a tela não é implementada. **Opcional:** sem ele, o agente segue o `design-system.md`.

## Fatia 2. Conta e perfil

Detalhe de cada tela em `docs/ui/telas.md`, seção 5. Textos em `docs/copy.md`, seção 6.

| Arquivo | Tela | Status |
|---------|------|--------|
| `login.png` | Login, completado | Obrigatório |
| `signup.png` | Cadastro | Obrigatório |
| `confirmEmail.png` | Confirmar e-mail (código) | Obrigatório |
| `forgotPassword-etapa1.png` e `forgotPassword-etapa2.png` | Recuperar senha | Obrigatório |
| `terms.png` | Aceite dos termos | Obrigatório |
| `termsDocument.png` | Texto de um documento (provisório) | Opcional |
| `profile.png` e `profile-google.png` | Meu perfil, com e sem acesso por e-mail e senha | Obrigatório |
| `profileEdit.png` e `profileEdit-foto.png` | Editar perfil e a sheet da foto | Obrigatório |
| `profilePix.png` e `profilePix-remover.png` | Chave Pix e a confirmação de remoção | Obrigatório |
| `profilePix-tipo.png` | Chave Pix com o menu do tipo aberto | Extra, enviado pelo responsável |
| `profileEmail-etapa1.png` e `profileEmail-etapa2.png` | Trocar e-mail | Obrigatório |
| `profilePassword.png` | Trocar senha | Obrigatório |

### Conferência dos PNGs da fatia 2 (12/11/2026)

Todos os PNGs obrigatórios chegaram, com todos os elementos do briefing. Na implementação:

- **A folha da foto não tem título.** O PNG mostra "Foto do perfil", mas o responsável decidiu tirar. "Remover foto" fica em tom destrutivo e sem confirmação.
- **No título "Confirme o seu e-mail", o hífen não quebra** (U+2011). O PNG mostra a quebra "e-" / "mail", que não deve acontecer.
- O tipo da chave Pix é um menu suspenso com ícones (`profilePix-tipo.png`), e não chips.
- Os ícones decorativos (quadrado amarelo na confirmação e no aceite, ícones nas linhas, relógio no reenviar) e o bloco amarelo do login seguem os PNGs.

### `login.png`. Login (`/login`)

O login da fatia 1 continua (espaço do logo com `VoleiIn`, subtítulo, campos E-mail e Senha com o olho de mostrar a senha, botão principal Entrar). Acrescentar:

- botão de texto **Esqueci minha senha**, ligado ao campo Senha;
- divisor com **ou**;
- botão de contorno **Continuar com Google**;
- no pé, a frase **Não tem conta?** e o botão de texto **Criar conta**.

### `signup.png`. Cadastro (`/signup`)

- Barra superior interna: voltar e o título **Criar conta**.
- Frase de apoio.
- Campos **Nome**, **E-mail** e **Senha** (com o olho), e a dica **Pelo menos 8 caracteres** abaixo da senha.
- Botão principal **Criar conta**.
- No pé: **Já tem conta?** e o botão de texto **Entrar**.
- Sem caixa de aceite dos termos.

### `confirmEmail.png`. Confirmar e-mail (`/confirm-email`)

- Título **Confirme o seu e-mail**.
- A frase com o e-mail: "Enviamos um código de 6 dígitos para ana@exemplo.com."
- **Campo de código de 6 dígitos.** A forma é sua: um campo só ou seis casas.
- Botão principal **Confirmar**.
- Botão de texto **Reenviar código**, que fica desabilitado com uma contagem ("Reenviar código em 45 s"). Mostre o estado que preferir.
- Frase de ajuda em tom secundário: "Não chegou? Confira o spam. Se este e-mail já tem conta, entre ou recupere a senha."
- Botão de texto **Usar outro e-mail**.

### `forgotPassword-etapa1.png` e `-etapa2.png`. Recuperar senha (`/forgot-password`)

- Barra superior interna: voltar e o título **Recuperar senha**.
- **Etapa 1:** frase de apoio, campo **E-mail** e botão principal **Enviar código**.
- **Etapa 2:** a frase com o e-mail, o campo de código (igual ao da `confirmEmail`), o campo **Nova senha** com o olho, o botão principal **Salvar nova senha** e o **Reenviar código**.

### `terms.png`. Aceite dos termos (`/terms`)

- Sem barra inferior e sem voltar.
- Título **Antes de continuar** e frase de apoio.
- Duas linhas com seta, uma por documento: **Termos de Uso** e **Política de Privacidade**, cada uma com o subtítulo **Versão 1.0**.
- Caixa de seleção **Li e aceito os Termos de Uso e a Política de Privacidade**.
- Botão principal **Aceitar e continuar**. Mostre-o desabilitado (caixa desmarcada) ou habilitado, como preferir.
- Botão de texto **Sair**.

### `termsDocument.png`. Texto de um documento (`/terms/:document`), opcional

- Barra superior interna: voltar e o nome do documento.
- Corpo de texto rolável. Por enquanto, uma frase provisória.

### `profile.png` e `profile-google.png`. Meu perfil (`/profile`)

- Barra superior de raiz com o título **Perfil**. A barra inferior aparece, com a aba Perfil ativa.
- Cabeçalho: **avatar de 72** (foto ou iniciais sobre pastel, `design-system.md`, 3.4), o **nome exibido** (apelido ou nome) e o **e-mail** da conta.
- Lista de linhas com seta:
  - **Editar perfil**, com o subtítulo "Nome, apelido, foto e telefone";
  - **Chave Pix**, com o subtítulo "CPF · 529.982.247-25" ou "Não cadastrada";
  - **Trocar e-mail** e **Trocar senha**.
- Botão de contorno **Sair**.
- **`profile-google.png`:** a mesma tela sem as linhas Trocar e-mail e Trocar senha (conta que entrou só pelo Google).

### `profileEdit.png` e `profileEdit-foto.png`. Editar perfil (`/profile/edit`)

- Barra superior interna: voltar e o título **Editar perfil**.
- **Avatar de 96** com o botão de texto **Trocar foto**.
- Campos **Nome** e **Apelido**, este com a dica "Aparece no lugar do nome nas listas".
- Campo **Telefone** com o prefixo fixo **+55** e a máscara `(86) 99999-1234`.
- Interruptor **Mostrar meu telefone**, com a dica "Quem estiver nos seus grupos e jogos poderá ver".
- Botão principal **Salvar**.
- **`profileEdit-foto.png`:** a sheet que abre em Trocar foto, com **Escolher da galeria**, **Tirar foto** e **Remover foto**.

### `profilePix.png` e `profilePix-remover.png`. Chave Pix (`/profile/pix`)

- Barra superior interna: voltar e o título **Chave Pix**.
- Rótulo **Tipo da chave** e cinco opções: **CPF**, **CNPJ**, **E-mail**, **Telefone** e **Aleatória**. O documento sugere chips, mas a forma é sua.
- Campo **Chave**, com a máscara do tipo escolhido (no exemplo, CPF `529.982.247-25`).
- Botão principal **Salvar**.
- Botão destrutivo de contorno **Remover chave**, quando já há chave.
- **`profilePix-remover.png`:** a confirmação, com o título **Remover a chave Pix?**, a frase "Sem chave Pix, você não pode ser recebedor de jogos.", o botão destrutivo sólido **Remover** e o botão de contorno **Voltar** (`design-system.md`, 7.15).

### `profileEmail-etapa1.png` e `-etapa2.png`. Trocar e-mail (`/profile/email`)

- Barra superior interna: voltar e o título **Trocar e-mail**.
- **Etapa 1:** o texto "E-mail atual: ana@exemplo.com", o campo **Novo e-mail**, a frase "Até você digitar o código, o e-mail atual continua valendo." e o botão principal **Enviar código**.
- **Etapa 2:** a frase com o novo e-mail, o campo de código, o botão principal **Confirmar** e o **Reenviar código**.

### `profilePassword.png`. Trocar senha (`/profile/password`)

- Barra superior interna: voltar e o título **Trocar senha**.
- Campos **Senha atual** e **Nova senha**, ambos com o olho.
- Botão principal **Salvar**.
