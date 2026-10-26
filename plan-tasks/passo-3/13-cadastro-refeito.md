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

- [ ] A3 aberta pela A2 recebe o nome e a senha. Depois do `verifyOTP`, `updateUser(password)`, ignorando `same_password`, e `update` de `pessoa.nome` quando difere do digitado. Pela A1 nada muda: a senha digitada ali já é a da conta, porque o serviço responde `invalid_credentials` antes de `email_not_confirmed`.
- [ ] O nome no início: a `Raiz` troca a A1 pelo início assim que a sessão nasce, e o `meuNomeProvider` pode ler o nome antigo antes do `update`. Conferir e, se for o caso, refazer a leitura depois da gravação.
- [ ] Falha entre o código e a gravação (sem conexão, por exemplo): a sessão já existe e a senha do primeiro pedido ainda vale. Se o caminho não for óbvio, perguntar ao Thiago antes de codar.
- [ ] `auth_falso.dart` e os testes de widget da A3: aberta pela A2, a confirmação grava nome e senha; aberta pela A1, não grava.
- [ ] Cenário no `supabase/testes/autenticacao_api.sh`: impostor pendente, cadastro refeito depois de 60 s com outra senha e outro nome, código, `PUT /user` e `update` de `pessoa`; a senha do impostor é recusada, a da dona entra, e `pessoa.nome` é o da dona.
- [ ] Conferir no celular: o recadastro pela A2 entra como "Olá, <nome da A2>", e a senha da A2 entra depois de "Sair".
- [ ] `flutter test`, `dart analyze` e as suítes passam.

## Pronto quando

Depois do cadastro refeito e confirmado, valem o nome e a senha do último pedido, e a senha do primeiro é recusada, no script e no celular.

## Commit

`Grava o nome e a senha do cadastro refeito`
