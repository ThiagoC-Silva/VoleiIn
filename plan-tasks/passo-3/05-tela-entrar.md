# T05 — Tela de entrar (RF01)

**Estado:** feito · **Depende de:** T02, T03, T04

## Objetivo

Entrar e criar conta numa tela só (RF01, RN21, RNF06):
- e-mail e senha, ou Google;
- cadastro com nome, e-mail e senha, concluído pelo código de seis dígitos, com reenvio depois de 60 s.

O caminho de "Esqueci a senha" entra na T12. Sem especificação de tela: o design será refeito depois.

## Reescrita em 2026-10-20 — senha e Google

A tela entregue pedia o código a cada entrada. Ela entrou em `a9a99cf` e os testes em `05135b9`. O acesso passou a ser por senha ou Google, e o código fica só na confirmação do cadastro (ver as decisões no [README](README.md) e `docs/stack.md`, Autenticação). Esta task substitui aquela tela e os testes dela.

## O que falta

- [x] `app/lib/dados/auth_repositorio.dart`:
  - saem `pedirCodigo` e o `criarConta` por `signInWithOtp`.
  - `entrar(email, senha)` — `signInWithPassword`.
    - Devolve `false` quando o serviço responde `email_not_confirmed`, depois de reenviar o código (`resend(type: OtpType.signup)`), para a tela ir à etapa do código.
    - É o mesmo desenho do `pedirCodigo` de antes, que devolvia `false` para conta inexistente.
  - `criarConta(nome, email, senha)` — `signUp(email:, password:, data: {'nome': nome})`. E-mail que já tem conta vira `FalhaAuth('Esse e-mail já tem conta. Entre com a senha ou pelo Google.')`. O serviço sinaliza isso de um de dois jeitos, e o app trata os dois:
    - o erro `user_already_exists`, que é o que o Auth local devolve (sonda da T02);
    - um usuário sem `identities`, quando o serviço esconde a conta.
  - `confirmarCadastro(email, codigo)` — `verifyOTP(type: OtpType.email)`.
  - `reenviarConfirmacao(email)` — `resend(type: OtpType.signup)`.
  - `entrarComGoogle()` — `GoogleSignIn.instance.authenticate()`, depois o ID token, depois `signInWithIdToken(provider: OAuthProvider.google, idToken: ...)`. Cancelar o seletor de contas não é erro e não mostra mensagem.
  - `sair()` — também `GoogleSignIn.instance.signOut()`, para o seletor de contas voltar a aparecer na próxima entrada.
  - `_traduzir`:
    - entram `invalid_credentials` ("E-mail ou senha incorretos."), `weak_password` ("A senha precisa de pelo menos 8 caracteres."), `user_already_exists` (a mensagem do `criarConta` acima) e `same_password`;
    - os demais ficam;
    - os códigos reais se conferem na T07.
  - Comentário da classe de acordo: senha ou Google; código só no cadastro, na redefinição e na troca.
- [x] `app/lib/features/auth/entrar_tela.dart`:
  - etapas:
    - `entrar`: e-mail, senha, "Entrar", "Entrar com Google" e "Criar conta";
    - `cadastro`: nome, e-mail e senha;
    - `codigo`: `EtapaCodigo`, com reenvio por `reenviarConfirmacao`;
  - `entrar` que devolve `false` vai direto ao código;
  - senha com `obscureText`; menos de 8 caracteres é recusada na tela, sem chamar o serviço;
  - voltar do cadastro e do código para `entrar`.
- [x] `app/lib/dados/pessoa_repositorio.dart`: comentário. A linha nasce na confirmação do cadastro ou no primeiro acesso pelo Google.
- [x] `app/test/auth_falso.dart` com os métodos novos, e `app/test/features/auth/entrar_tela_test.dart` refeito:
  - senha certa chama `entrar` com o e-mail aparado e minúsculo;
  - senha errada mostra a mensagem e fica na etapa;
  - conta não confirmada vai ao código; confirmar chama `confirmarCadastro`; reenvio depois de 60 s chama `reenviarConfirmacao`;
  - cadastro chama `criarConta` com nome e e-mail aparados e vai ao código;
  - senha curta e nome vazio são recusados sem chamar o serviço;
  - e-mail que já tem conta mostra a mensagem e não avança;
  - "Entrar com Google" chama `entrarComGoogle`;
  - voltar do código para `entrar`.

## Feito em 2026-10-22

As telas saíram com o design de `docs/design/telas/01-acesso/` (A1 Entrar, A2 Criar conta, A3 Confirmar e-mail), sobre a base escura do design system criada no commit anterior. Isso derruba o "sem especificação de tela" que a T10 ia registrar como aberto.

- As três etapas viraram três rotas, como no desenho: a A1 é a raiz sem sessão; a A2 abre por cima e dá lugar à A3 (`pushReplacement`), então voltar do código leva à entrada. Ao confirmar o código, a A3 desfaz a pilha até a raiz, porque a `Raiz` troca a entrada pelo início por baixo dela.
- O código usa as seis casas do design (`app/lib/core/widgets/campo_codigo.dart`), e a `etapa_codigo.dart` saiu: a contagem de 60 s foi para `reenvio_codigo.dart`.
- `entrar` que encontra `over_email_send_rate_limit` ao reenviar o código de um cadastro pendente segue para a A3 mesmo assim: o código enviado há menos de um minuto continua valendo.
- Os erros do `google_sign_in` já têm mensagem por código (`interrupted`/`uiUnavailable`, `clientConfigurationError`/`providerConfigurationError`, demais). O código real do SHA-1 ausente se confere na T07, cenário 22.
- O `AuthRepositorio` recebe o `GoogleSignIn` no construtor, junto do `GoTrueClient`.
- "Esqueci a senha" na A1 entra com a T12.
- `dart analyze` sem erro; `flutter test` com 17 testes (A1, A2, A3 e troca de e-mail).

## O que já existe

- `app/lib/features/auth/etapa_codigo.dart` — campo de código e contagem de 60 s para o reenvio, reaproveitado aqui, na T06 e na T12.
- A tela e os testes por código (`a9a99cf`, `05135b9`), que esta task substitui. A extração do fake para `app/test/auth_falso.dart` continua valendo.

## Pronto quando

`cd app && flutter test` e `dart analyze` passam.

## Commit

`Troca a entrada por código por e-mail e senha ou Google`
