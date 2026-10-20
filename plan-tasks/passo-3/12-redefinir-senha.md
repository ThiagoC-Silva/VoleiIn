# T12 — Redefinição e troca de senha (RF41)

**Estado:** a fazer · **Depende de:** T05

## Objetivo

Redefinir a senha por código enviado ao e-mail, num caminho só, para a senha esquecida e para a troca a partir da sessão ativa (RF41, RN21). É também o caminho de quem entra só pelo Google criar uma senha.

Ao concluir:
- as outras sessões caem e a deste aparelho continua (RNF07);
- os aparelhos de push são apagados pelo gatilho da T03;
- o aviso de senha trocada sai pelo serviço (T02).

## O que falta

- [ ] `app/lib/dados/auth_repositorio.dart`:
  - `pedirRedefinicao(email)` — `resetPasswordForEmail(email)`;
  - `redefinirSenha(email, codigo, nova)` — `verifyOTP(type: OtpType.recovery)`, depois `updateUser(UserAttributes(password: nova))`, depois `signOut(scope: SignOutScope.others)`, numa cadeia só.
- [ ] `app/lib/features/auth/redefinir_senha_tela.dart`:
  - etapa do e-mail → etapa do código **com o campo de senha nova**; reenvio depois de 60 s por `pedirRedefinicao`.
  - A senha nova (mínimo 8) é pedida e validada **antes** da conferência do código, porque a sessão nasce no `verifyOTP`. Sem sessão anterior, a `Raiz` troca a tela de entrar pelo início nesse instante. A cadeia segue no repositório, mas a tela já não está lá para mostrar um erro.
  - Depois do pedido, a mensagem é "Se houver conta com esse e-mail, enviamos um código", porque o serviço responde igual para e-mail sem conta.
  - Aberta por dois caminhos:
    - "Esqueci a senha" na `EntrarTela`, com o e-mail já digitado;
    - "Trocar senha" na `InicioTela`, com o e-mail atual travado. Nesse caso, ao concluir, mostra um snackbar e fecha, como a `TrocarEmailTela`.
- [ ] `app/lib/features/auth/etapa_codigo.dart`: campo extra opcional abaixo do código (a senha nova), que entra na condição do botão Confirmar. Os usos atuais não mudam.
- [ ] `app/lib/features/auth/entrar_tela.dart`: botão "Esqueci a senha" na etapa de entrar.
- [ ] `app/lib/features/feed/inicio_tela.dart`: botão "Trocar senha".
- [ ] `app/test/auth_falso.dart` com os métodos novos, e `app/test/features/auth/redefinir_senha_tela_test.dart`:
  - o pedido chama `pedirRedefinicao` com o e-mail aparado e vai ao código;
  - senha nova curta é recusada sem chamar `redefinirSenha`;
  - código e senha chamam `redefinirSenha(email, codigo, nova)`;
  - o reenvio depois de 60 s chama `pedirRedefinicao` de novo;
  - aberta pela sessão, o e-mail vem travado no atual.

## Pronto quando

`cd app && flutter test` e `dart analyze` passam. O fluxo real é conferido na T07 (cenários 9 a 12 e 21).

## Commit

`Cria a redefinição e a troca de senha por código`
