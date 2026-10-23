# T07.8 — Celular: cenários de e-mail e senha

**Estado:** a fazer · **Depende de:** T07.7

## Objetivo

Ver no app o que o script provou no servidor: as telas A1 a A4 e a troca de e-mail chegam ao estado certo e mostram as mensagens certas.

## O que já existe

- O app instalado e operável pelo `adb` (T07.7).
- O script, para preparar o lado do servidor (segunda sessão, linhas em `dispositivo_push`).

## O que falta

Operado pelo Claude, com captura de cada estado. Códigos lidos pela API do Mailpit; pessoas novas com `email_unico`.

- [ ] **1** — A1 → "Criar conta" → A2 com nome, e-mail e senha → A3 → código → início com "Olá, <nome>". Antes do código, `pessoa` sem a linha.
- [ ] **2** — "Sair" e entrar com e-mail e senha; nenhum e-mail chega.
- [ ] **3** — senha errada: "E-mail ou senha incorretos." acima do botão, e a A1 continua.
- [ ] **5** — A2 com o e-mail do 1: "Esse e-mail já tem conta. Entre com a senha ou pelo Google." e não avança.
- [ ] **6** — cadastro que para na A3 (voltar), depois entrar com a senha na A1: vai para a A3 com código novo; confirmar entra.
- [ ] **9** — com uma segunda sessão por `curl` e duas linhas em `dispositivo_push`:
  - "Esqueci a senha" na A1 → e-mail já digitado → A4 → código e senha nova;
  - o snackbar aparece e o app cai no início;
  - pelo servidor: refresh da segunda sessão recusado e linhas apagadas.
- [ ] **9 pela sessão** — "Trocar senha" no início: e-mail travado, código, senha nova, snackbar e volta ao início logado.
- [ ] **13** — "Trocar e-mail" no início → endereço novo → código → snackbar; o início mostra o e-mail novo; o aviso chega no antigo.
- [ ] **16** — trocar para o e-mail de outra conta: "Esse e-mail já pertence a outra conta." e não avança.
- [ ] Reenvio: na A3, a contagem de 60 s termina e "Reenviar" manda outro código.

## Resultado

_Preenchido na execução: cada cenário com o que a tela mostrou; divergências de texto contra os PNGs vão para `docs/design/telas/01-acesso/implementacao.md`._

## Pronto quando

Os dez itens acima rodaram, cada um com o resultado anotado, e as divergências estão corrigidas ou registradas.

## Commit

Um por correção que algum cenário exigir. Sem correção, sem commit.
