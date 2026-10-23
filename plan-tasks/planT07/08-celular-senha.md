# T07.8 — Celular: cenários de e-mail e senha

**Estado:** feito · **Depende de:** T07.7

## Objetivo

Ver no app o que o script provou no servidor: as telas A1 a A4 e a troca de e-mail chegam ao estado certo e mostram as mensagens certas.

## O que já existe

- O app instalado e operável pelo `adb` (T07.7).
- O script, para preparar o lado do servidor (segunda sessão, linhas em `dispositivo_push`).

## O que falta

Operado pelo Claude, com captura de cada estado. Códigos lidos pela API do Mailpit; pessoas novas com `email_unico`.

- [x] **1** — A1 → "Criar conta" → A2 com nome, e-mail e senha → A3 → código → início com "Olá, <nome>". Antes do código, `pessoa` sem a linha.
- [x] **2** — "Sair" e entrar com e-mail e senha; nenhum e-mail chega.
- [x] **3** — senha errada: "E-mail ou senha incorretos." acima do botão, e a A1 continua.
- [x] **5** — A2 com o e-mail do 1: "Esse e-mail já tem conta. Entre com a senha ou pelo Google." e não avança.
- [x] **6** — cadastro que para na A3 (voltar), depois entrar com a senha na A1: vai para a A3 com código novo; confirmar entra.
- [x] **9** — com uma segunda sessão por `curl` e duas linhas em `dispositivo_push`:
  - "Esqueci a senha" na A1 → e-mail já digitado → A4 → código e senha nova;
  - o snackbar aparece e o app cai no início;
  - pelo servidor: refresh da segunda sessão recusado e linhas apagadas.
- [x] **9 pela sessão** — "Trocar senha" no início: e-mail travado, código, senha nova, snackbar e volta ao início logado.
- [x] **13** — "Trocar e-mail" no início → endereço novo → código → snackbar; o início mostra o e-mail novo; o aviso chega no antigo.
- [x] **16** — trocar para o e-mail de outra conta: "Esse e-mail já pertence a outra conta." e não avança.
- [x] Reenvio: na A3, a contagem de 60 s termina e "Reenviar" manda outro código.

## Resultado

Executado em 2026-10-23 no Motorola Edge 60 Pro, máquina em `192.168.2.110`, operado pelo `adb`. Pessoas novas com e-mail único (`carla.<epoch>@exemplo.com`, `edu.…`, `fabio.…`, `gabi.…`, `hugo.…`). Capturas no scratchpad da sessão, não versionadas.

| # | O que a tela mostrou | Servidor |
| --- | --- | --- |
| 1 | A1 → "Criar conta" → A2 com nome, e-mail e senha → A3 com "Enviamos um código de 6 dígitos para **carla…**. Ele vale por 5 minutos." e a contagem → seis dígitos → início com "Olá, Carla" e o e-mail | antes do código: usuário não confirmado e **sem** `pessoa`; depois: `pessoa.nome = Carla`, mesmo id de `auth.users` |
| 2 | "Sair" → A1 → e-mail e senha → início | nenhum e-mail novo |
| 3 | "E-mail ou senha incorretos." com o ícone de erro, acima do "Entrar"; continua na A1 com os campos preenchidos | nenhum e-mail |
| 5 | A2 com o e-mail da Carla: "Esse e-mail já tem conta. Entre com a senha ou pelo Google." acima do botão; não avança | nenhum e-mail |
| 6 | Cadastro do Edu até a A3, "Voltar" leva à A1. Entrar com a senha **dentro** dos 60 s: vai à A3 sem e-mail novo (o reenvio recusado é engolido e o código anterior vale). **Depois** dos 60 s: vai à A3 e chega código novo; o código antigo é recusado com "Código inválido ou vencido. Confira ou peça outro."; o novo entra com "Olá, Edu" | pendente sem `pessoa` até o código |
| 9 | Duas linhas em `dispositivo_push` e uma segunda sessão por `curl`. A1 com o e-mail → "Esqueci a senha" → A4 com o e-mail já digitado → "Enviar código" → "Se houver conta com **x**, enviamos um código…" → código e senha nova → snackbar "Senha trocada. Os outros aparelhos foram desconectados." e início | refresh da segunda sessão: `refresh_token_not_found`; linhas de `dispositivo_push`: 0; chegou "A senha da sua conta no VoleiIn foi trocada"; senha antiga `invalid_credentials`, nova entra |
| 9 pela sessão | "Trocar senha" → A4 com o e-mail travado e "Vamos enviar um código para o e-mail da sua conta…" → "Digite o código enviado para **x** e escolha a nova senha." (o texto do PNG) → snackbar e início logado | a outra sessão aberta caiu (de 2 para 1 em `auth.sessions`); aviso de senha trocada |
| 13 | "Trocar e-mail" → endereço novo → código → snackbar "E-mail trocado. Os outros aparelhos foram desconectados." → o início mostra o e-mail novo | código só no novo; "O e-mail da sua conta no VoleiIn foi trocado" no antigo; `auth.users.email` trocado |
| 16 | Troca para o e-mail da Carla: "Esse e-mail já pertence a outra conta." e fica na etapa do e-mail | nenhum e-mail para a Carla |
| Reenvio | A3: a contagem chega a zero, a pílula vira "Reenviar código", o toque manda outro código e a contagem recomeça em 60 s; o segundo código confirma | dois e-mails de confirmação |

Textos de A1 a A4 conferidos contra os PNGs: **nenhuma divergência**. O título da A1 cabe numa linha neste aparelho, mais largo que o do desenho.

**Correções** (cada uma com teste de widget e conferida de novo no celular):
- **Foco das casas do código** (`Devolve o foco às casas do código depois da chamada`): depois do código recusado (6) e do reenvio, o campo travado durante a chamada perdia o foco, o teclado fechava e o código digitado em seguida se perdia. O `CampoCodigo` agora devolve o foco ao ser destravado, se o tinha ao ser travado. Vale para A3, A4 e troca de e-mail.
- **Senha recusada depois do código conferido** (`Confere o código da redefinição uma vez só`): o cenário 11 que a T07.6 deixou para cá. Pela A1, com a senha nova igual à atual, a A4 mostra "A senha nova precisa ser diferente da atual." e fica, mas a conferência já criou a sessão e gastou o código: a segunda tentativa, com outra senha, recebia "Código inválido ou vencido". Agora a A4 confere o código uma vez só e, nas tentativas seguintes, só grava a senha. Conferido: a segunda tentativa troca a senha, e a antiga passa a ser recusada.

**Observado, sem correção:**
- Cenário 11: com a sessão criada pela conferência do código e a senha ainda não trocada, "Voltar" na A4 leva ao início **logado**. A posse do e-mail foi provada pelo código, então não há brecha; fica anotado para a T07.11.
- Cenário 6, segundo cadastro pendente com outro nome e outra senha (o outro ponto que a T07.6 deixou para cá): passados os 60 s, a A2 aceita sem aviso, a A3 abre e chega código novo; a confirmação entra como "Olá, Hugo", o nome do **primeiro** cadastro, e só a primeira senha vale. Igual ao que a API mostrou. **Decisão de produto aberta**, para a T07.11 levar ao Thiago.
- Dentro dos 60 s, a A3 aberta pela entrada recomeça a contagem em 60, embora a janela do servidor tenha começado no primeiro envio. Só atrasa o toque possível; sem efeito.

**Para a T07.9 (operação pelo `adb`):**
- O campo invisível das casas não aparece no `uiautomator dump`; o texto vai por `input text` com o foco nele, e as casas aparecem como seis nós com os dígitos.
- Depois de voltar da A3, o dump da A1 veio uma vez sem "Entrar com Google" e o rodapé, que estavam na tela; o toque foi por coordenada da captura.
- Digitar logo depois do `input tap` perde o primeiro caractere: esperar ~1 s. `ctrl+a` não seleciona no Flutter; limpar com `KEYCODE_MOVE_END` e `KEYCODE_DEL`.
- O "voltar" usado para fechar o teclado sai do app se o teclado já estiver fechado; um toque que falha antes dele leva ao lançador.
- O Gboard **não** entrou em modo de teclado físico depois de dezenas de `input text`: `mInputShown=true` nas casas até o fim.

## Pronto quando

Os dez itens acima rodaram, cada um com o resultado anotado, e as divergências estão corrigidas ou registradas.

## Commit

Um por correção que algum cenário exigir, e um último com o registro da task. Correções: `Devolve o foco às casas do código depois da chamada` e `Confere o código da redefinição uma vez só`; registro: `Registra a rodada de e-mail e senha no celular`.
