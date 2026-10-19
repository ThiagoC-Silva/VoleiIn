# T06 — Tela de trocar e-mail (RF35)

**Estado:** parcial · **Depende de:** T04

## Objetivo

Trocar o e-mail a partir da sessão ativa (RF35, RN21): código no endereço novo, aviso no antigo, e as sessões dos outros aparelhos caem ao confirmar; a deste aparelho continua (RNF07). E-mail que já pertence a outra conta bloqueia a troca.

## O que já existe

- `app/lib/dados/auth_repositorio.dart` — `pedirTrocaEmail` (`updateUser(email: novo)`) e `confirmarTrocaEmail` (`verifyOTP(type: emailChange)` seguido de `signOut(scope: others)`).
- `app/lib/features/perfil/trocar_email_tela.dart` — recusa o mesmo e-mail atual, envia o código, mostra `EtapaCodigo`, e no sucesso exibe um snackbar e fecha a tela.
- Os aparelhos de push são apagados pelo gatilho da T03, não pelo app.

Tudo commitado em `a9a99cf`.

## O que falta

- [ ] `app/test/features/perfil/trocar_email_tela_test.dart`, com um `AuthRepositorio` falso como em `entrar_tela_test.dart`:
  - e-mail igual ao atual mostra "Esse já é o e-mail da sua conta." e não chama `pedirTrocaEmail`;
  - `FalhaAuth('Esse e-mail já pertence a outra conta.')` em `pedirTrocaEmail` mostra a mensagem e não avança para o código;
  - código confirmado chama `confirmarTrocaEmail(novo, codigo)`, mostra o snackbar e fecha a tela;
  - reenvio depois de 60 s chama `pedirTrocaEmail` de novo.
- [ ] Se o falso for igual ao da T05, extrair para `app/test/auth_falso.dart` e reaproveitar nos dois arquivos.

## Pronto quando

`cd app && flutter test` passa, com os testes novos.

## Commit

A tela já entrou em `a9a99cf`. O que falta vai em: `Cria os testes da tela de trocar e-mail`
