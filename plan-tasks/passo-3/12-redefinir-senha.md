# T12 — Redefinição e troca de senha (RF41)

**Estado:** feito · **Depende de:** T05

## Objetivo

Redefinir a senha por código enviado ao e-mail, num caminho só, para a senha esquecida e para a troca a partir da sessão ativa (RF41, RN21). É também o caminho de quem entra só pelo Google criar uma senha.

Ao concluir:
- as outras sessões caem e a deste aparelho continua (RNF07);
- os aparelhos de push são apagados pelo gatilho da T03;
- o aviso de senha trocada sai pelo serviço (T02).

## O que falta

- [x] `app/lib/dados/auth_repositorio.dart`:
  - `pedirRedefinicao(email)` — `resetPasswordForEmail(email)`;
  - `redefinirSenha(email, codigo, nova)` — `verifyOTP(type: OtpType.recovery)`, depois `updateUser(UserAttributes(password: nova))`, depois `signOut(scope: SignOutScope.others)`, numa cadeia só.
- [x] `app/lib/features/auth/redefinir_senha_tela.dart`:
  - etapa do e-mail → etapa do código **com o campo de senha nova**; reenvio depois de 60 s por `pedirRedefinicao`.
  - A senha nova (mínimo 8) é pedida e validada **antes** da conferência do código, porque a sessão nasce no `verifyOTP`. Sem sessão anterior, a `Raiz` troca a tela de entrar pelo início nesse instante. A cadeia segue no repositório, mas a tela já não está lá para mostrar um erro.
  - Depois do pedido, a mensagem é "Se houver conta com esse e-mail, enviamos um código", porque o serviço responde igual para e-mail sem conta.
  - Aberta por dois caminhos:
    - "Esqueci a senha" na `EntrarTela`, com o e-mail já digitado;
    - "Trocar senha" na `InicioTela`, com o e-mail atual travado. Nesse caso, ao concluir, mostra um snackbar e fecha, como a `TrocarEmailTela`.
- [x] ~~`etapa_codigo.dart`: campo extra opcional abaixo do código~~ — a `etapa_codigo.dart` saiu na T05; a A4 monta as seis casas, o reenvio e o campo de senha nova lado a lado (ver "Feito em 2026-10-22").
- [x] `app/lib/features/auth/entrar_tela.dart`: botão "Esqueci a senha" na etapa de entrar.
- [x] `app/lib/features/feed/inicio_tela.dart`: botão "Trocar senha".
- [x] `app/test/auth_falso.dart` com os métodos novos, e `app/test/features/auth/redefinir_senha_tela_test.dart`:
  - o pedido chama `pedirRedefinicao` com o e-mail aparado e vai ao código;
  - senha nova curta é recusada sem chamar `redefinirSenha`;
  - código e senha chamam `redefinirSenha(email, codigo, nova)`;
  - o reenvio depois de 60 s chama `pedirRedefinicao` de novo;
  - aberta pela sessão, o e-mail vem travado no atual.

## Feito em 2026-10-22

A tela saiu com o design da A4 (`docs/design/telas/01-acesso/A4-redefinir-senha.png`). O que o desenho não mostra ou que diverge dele está em `docs/design/telas/01-acesso/implementacao.md`.

- A `etapa_codigo.dart` não ganhou o campo extra: saiu na T05. A A4 monta as seis casas (`campo_codigo.dart`), o reenvio (`reenvio_codigo.dart`) e o campo de senha nova lado a lado.
- A etapa do e-mail existe nos dois caminhos. Pela sessão, o campo vem travado e um toque em "Enviar código" manda o código, em vez de enviar sozinho ao abrir a tela: abrir por engano não gasta um e-mail da cota.
- Ao concluir, a tela mostra o snackbar e volta à raiz nos dois caminhos. Sem sessão anterior, a raiz já trocou a entrada pelo início por baixo da A4; pela sessão, o início está logo abaixo.
- A pilha de rotas mantém a A4 de pé enquanto a cadeia `verifyOTP` → `updateUser` → `signOut(others)` termina, então um erro depois da conferência do código (`same_password`, por exemplo) ainda aparece na tela. A senha continua conferida antes, como decidido.
- `dart analyze` sem erro; `flutter test` com 24 testes.

## Pronto quando

`cd app && flutter test` e `dart analyze` passam. O fluxo real é conferido na T07 (cenários 9 a 12 e 21).

## Commit

`Cria a redefinição e a troca de senha por código`
