# T13 — Nome e senha do cadastro refeito

**Estado:** feito · **Depende de:** T07

## Objetivo

Fechar a tomada de conta pelo cadastro refeito, achada na T07 (cenário 6) e decidida pelo Thiago em 2026-10-26 (`docs/prd.md`, RN21 e decisão "Cadastro com senha"; `docs/stack.md`, Autenticação).

O caso: o Bruno cadastra o e-mail da Carla e não confirma. A Carla faz o próprio cadastro na A2 com outra senha, recebe o código e confirma. O serviço fica com a senha e o nome do **primeiro** pedido. A conta nasce como "Impostor", a senha do Bruno entra e a da Carla é recusada. Conferido pela API local em 2026-10-26.

A decisão: depois do código de um cadastro vindo da A2, o app grava, com a sessão que acabou de nascer, a senha e o nome digitados na A2.

## O que já existe

- `criarConta(nome, email, senha)` e `confirmarCadastro(email, codigo)` em `app/lib/dados/auth_repositorio.dart`; a A3 (`confirmar_email_tela.dart`) é aberta pela A2 (`criar_conta_tela.dart`) e pela A1 (`entrar_tela.dart`, cadastro pendente).
- A escrita direta em `pessoa.nome` é uma das permitidas ao app (passo 2).
- A sonda da API: `PUT /user` com a senha da A2, pela sessão do `/verify`, dá 200, a senha do impostor passa a dar `invalid_credentials`, e chega "A senha da sua conta no VoleiIn foi trocada". Com a mesma senha que já vale, 422 `same_password`.
- Os caminhos que concluem um cadastro pendente, conferidos na revisão de 2026-10-27:

  | Caminho da dona | Resultado | Onde se resolve |
  | --- | --- | --- |
  | A1 com a senha dela | `invalid_credentials`; não avança | sem brecha |
  | Google | o serviço descarta a senha do impostor; nome do Google | serviço (T07, cenário 19) |
  | A2 de novo → A3 | senha e nome do impostor | **esta task** |
  | A4, "Esqueci a senha" | o código chega, a conferência confirma a conta; senha da dona, nome do impostor | **fora desta task**: risco aceito pelo Thiago em 2026-10-27, até a H2 (`docs/prd.md`, RN21; `docs/stack.md`, Autenticação e Riscos) |

  A sonda da A4, no local: `/signup` do impostor, `/recover` da dona (chega "Seu código para redefinir a senha do VoleiIn"), `/verify` `recovery` (sessão, `email_confirmed_at` preenchido, `pessoa.nome` = "Impostor"), `PUT /user` com a senha da dona (200); a do impostor dá `invalid_credentials`, e a da dona entra.

## O que falta

- [x] A3 aberta pela A2 recebe o nome e a senha. Depois do `verifyOTP`, `update` de `pessoa.nome` com o digitado, sempre (comparar exigiria uma leitura a mais e dá o mesmo resultado), e então `updateUser(password)`, ignorando `same_password`. Pela A1 nada muda: a senha digitada ali já é a da conta, porque o serviço responde `invalid_credentials` antes de `email_not_confirmed`.
  - O `same_password` é apanhado antes do `_traduzir`, que o transforma em "A senha nova precisa ser diferente da atual." e o mostraria no caso comum.
  - O `update` de `pessoa` mora no `PessoaRepositorio`, que tem o cliente de dados; o `AuthRepositorio` só tem o `GoTrueClient`.
- [x] O nome no início. Conferido na revisão: o `meuNomeProvider` relê a cada emissão de `sessaoProvider`, e o `updateUser` emite `userUpdated`; se a senha fosse gravada antes do nome, a releitura podia pegar o nome antigo. Com `same_password` nada é emitido. Por isso o nome vem antes da senha, e a A3 invalida o `meuNomeProvider` no fim da gravação.
- [x] Falha entre o código e a gravação (sem conexão, por exemplo). **Decidido pelo Thiago em 2026-10-27: a A3 segura.**
  - A mensagem da falha aparece na A3, e "Confirmar" tenta de novo só a gravação, sem conferir o código, que já foi gasto. É o mesmo desenho do `_codigoConferido` da A4.
  - Enquanto a gravação não passa, o voltar fica bloqueado: o do topo e o do sistema (`PopScope`). Sem isso, voltar levaria ao início, que a raiz já pôs por baixo, com a senha do primeiro pedido valendo.
  - Nada é guardado no aparelho. Se o app for fechado nesse meio, vale a senha do primeiro pedido até a dona usar "Esqueci a senha". Aceito: exige impostor, queda de rede no intervalo da gravação e o app fechado.
- [x] `auth_falso.dart` e os testes de widget da A3:
  - aberta pela A2, a confirmação grava nome e senha; aberta pela A1, não grava;
  - `same_password` não aparece como erro;
  - falha na gravação: a mensagem aparece, o voltar está bloqueado, e o novo "Confirmar" não confere o código de novo.
- [x] Cenário no `supabase/testes/autenticacao_api.sh`: impostor pendente, cadastro refeito depois de 60 s com outra senha e outro nome, código, `PATCH /rest/v1/pessoa` e `PUT /user`; a senha do impostor é recusada, a da dona entra, e `pessoa.nome` é o da dona. A URL da API de dados sai do `AUTH_URL` (`/auth/v1` → `/rest/v1`). O cenário 6, que anota que o serviço fica com o primeiro pedido, continua: o serviço não mudou, e o cenário novo confere o que o app faz por cima.
- [x] O `nome` nos metadados de `auth.users` continua o do primeiro pedido. Nada o lê depois da confirmação (o gatilho só o usa ao criar a `pessoa`, e os modelos de e-mail não o mostram). Fica como está; registrar no Resultado.
- [x] Conferir no celular, contra o Supabase local: o recadastro pela A2 entra como "Olá, <nome da A2>", e a senha da A2 entra depois de "Sair".
- [x] `flutter test`, `dart analyze` e as suítes passam.

## Resultado

Feito em 2026-10-27.

- **App.** `AuthRepositorio.gravarSenhaDoCadastro` faz o `updateUser(password)` e engole só o `same_password`. `PessoaRepositorio.gravarNome` faz o `update` de `pessoa.nome` e devolve `FalhaAuth`: `PostgrestException` vira a mensagem genérica, e qualquer outra exceção, que é o cliente HTTP falhando sem resposta, vira "Sem conexão…". As duas mensagens passaram a ser constantes públicas em `auth_repositorio.dart`. A A2 passa `(nome, senha)` à A3; a A1 continua sem passar.
- **A3.** Confere o código uma vez só (`_codigoConferido`), grava o nome, depois a senha, e invalida o `meuNomeProvider`. Com o código gasto e a gravação pendente, `PopScope(canPop: false)`, o voltar do topo desabilitado, e as casas e o reenvio travados. Registrado em `docs/design/telas/01-acesso/implementacao.md`.
- **Testes de widget:** 36 passando, com quatro novos (A2 grava nome e senha, nessa ordem; A1 não grava; a gravação recusada segura a tela, e a nova tentativa não confere o código de novo; a A2 leva nome e senha à A3) e dois do repositório (`same_password` não é falha; outra recusa chega traduzida). Conferido que o teste do voltar falha com `canPop: true`. `PessoaFalsa` nova em `app/test/`, registrando na mesma lista do `AuthFalso`, para conferir a ordem.
- **Script:** cenário `refeito`, logo depois do 6. A rodada inteira passa com 18 cenários, em 2 min 46 s, e gasta 19 e-mails (a T09 foi atualizada). As suítes SQL seguem com 61, 69 e 36.
- **Celular** (motorola edge 60 pro, APK de depuração, Supabase local): impostor pendente pelo `--impostor`; a A2 refeita com "Helena" e `senha-da-helena` 60 s depois; código confirmado, e o início abriu com "Olá, Helena". Pelo servidor: `pessoa.nome` = Helena, a senha do impostor dá `invalid_credentials`, a da Helena entra, e chegou "A senha da sua conta no VoleiIn foi trocada". Depois de "Sair", a senha da Helena entrou, de novo com "Olá, Helena".
- **Metadados:** `raw_user_meta_data.nome` continua "Impostor", como previsto. Nada o lê depois da confirmação.
- O pareamento da depuração sem fio desta máquina tinha se perdido no celular: o `adb mdns services` achava o aparelho, mas o `adb connect` falhava. Resolvido com novo `adb pair`.

## Pronto quando

Depois do cadastro refeito e confirmado, valem o nome e a senha do último pedido, e a senha do primeiro é recusada, no script e no celular.

## Commit

`Grava o nome e a senha do cadastro refeito`
