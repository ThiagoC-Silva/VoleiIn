# T13 — Nome e senha do cadastro refeito

**Estado:** a fazer · **Depende de:** T07

## Objetivo

Fechar a tomada de conta pelo cadastro refeito, achada na T07 (cenário 6) e decidida pelo Thiago em 2026-10-26 (`docs/prd.md`, RN21 e decisão "Cadastro com senha"; `docs/stack.md`, Autenticação).

O caso: o Bruno cadastra o e-mail da Carla e não confirma. A Carla faz o próprio cadastro na A2 com outra senha, recebe o código e confirma. O serviço fica com a senha e o nome do **primeiro** pedido. A conta nasce como "Impostor", a senha do Bruno entra e a da Carla é recusada. Conferido pela API local em 2026-10-26.

A decisão: depois do código de um cadastro vindo da A2, o app grava, com a sessão que acabou de nascer, a senha e o nome digitados na A2.

## O que já existe

- `criarConta(nome, email, senha)` e `confirmarCadastro(email, codigo)` em `app/lib/dados/auth_repositorio.dart`; a A3 (`confirmar_email_tela.dart`) é aberta pela A2 (`criar_conta_tela.dart`) e pela A1 (`entrar_tela.dart`, cadastro pendente).
- A escrita direta em `pessoa.nome` é uma das permitidas ao app (passo 2).
- A sonda da API: `PUT /user` com a senha da A2, pela sessão do `/verify`, dá 200, a senha do impostor passa a dar `invalid_credentials`, e chega "A senha da sua conta no VoleiIn foi trocada". Com a mesma senha que já vale, 422 `same_password`.

## O que falta

- [ ] A3 aberta pela A2 recebe o nome e a senha. Depois do `verifyOTP`, `update` de `pessoa.nome` quando difere do digitado, e então `updateUser(password)`, ignorando `same_password`. Pela A1 nada muda: a senha digitada ali já é a da conta, porque o serviço responde `invalid_credentials` antes de `email_not_confirmed`.
  - O `same_password` é apanhado antes do `_traduzir`, que o transforma em "A senha nova precisa ser diferente da atual." e o mostraria no caso comum.
  - O `update` de `pessoa` mora no `PessoaRepositorio`, que tem o cliente de dados; o `AuthRepositorio` só tem o `GoTrueClient`.
- [ ] O nome no início. Conferido na revisão: o `meuNomeProvider` relê a cada emissão de `sessaoProvider`, e o `updateUser` emite `userUpdated`; se a senha fosse gravada antes do nome, a releitura podia pegar o nome antigo. Com `same_password` nada é emitido. Por isso o nome vem antes da senha, e a A3 invalida o `meuNomeProvider` no fim da gravação.
- [ ] Falha entre o código e a gravação (sem conexão, por exemplo). **Decidido pelo Thiago em 2026-10-27: a A3 segura.**
  - A mensagem da falha aparece na A3, e "Confirmar" tenta de novo só a gravação, sem conferir o código, que já foi gasto. É o mesmo desenho do `_codigoConferido` da A4.
  - Enquanto a gravação não passa, o voltar fica bloqueado: o do topo e o do sistema (`PopScope`). Sem isso, voltar levaria ao início, que a raiz já pôs por baixo, com a senha do primeiro pedido valendo.
  - Nada é guardado no aparelho. Se o app for fechado nesse meio, vale a senha do primeiro pedido até a dona usar "Esqueci a senha". Aceito: exige impostor, queda de rede no intervalo da gravação e o app fechado.
- [ ] `auth_falso.dart` e os testes de widget da A3:
  - aberta pela A2, a confirmação grava nome e senha; aberta pela A1, não grava;
  - `same_password` não aparece como erro;
  - falha na gravação: a mensagem aparece, o voltar está bloqueado, e o novo "Confirmar" não confere o código de novo.
- [ ] Cenário no `supabase/testes/autenticacao_api.sh`: impostor pendente, cadastro refeito depois de 60 s com outra senha e outro nome, código, `PATCH /rest/v1/pessoa` e `PUT /user`; a senha do impostor é recusada, a da dona entra, e `pessoa.nome` é o da dona. A URL da API de dados sai do `AUTH_URL` (`/auth/v1` → `/rest/v1`). O cenário 6, que anota que o serviço fica com o primeiro pedido, continua: o serviço não mudou, e o cenário novo confere o que o app faz por cima.
- [ ] O `nome` nos metadados de `auth.users` continua o do primeiro pedido. Nada o lê depois da confirmação (o gatilho só o usa ao criar a `pessoa`, e os modelos de e-mail não o mostram). Fica como está; registrar no Resultado.
- [ ] Conferir no celular, contra o Supabase local: o recadastro pela A2 entra como "Olá, <nome da A2>", e a senha da A2 entra depois de "Sair".
- [ ] `flutter test`, `dart analyze` e as suítes passam.

## Pronto quando

Depois do cadastro refeito e confirmado, valem o nome e a senha do último pedido, e a senha do primeiro é recusada, no script e no celular.

## Commit

`Grava o nome e a senha do cadastro refeito`
