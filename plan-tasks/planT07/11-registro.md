# T07.11 — Registro dos resultados e fechamento da T07

**Estado:** a fazer · **Depende de:** T07.10

## Objetivo

Consolidar em `plan-tasks/passo-3/` o que as tasks T07.2 a T07.10 anotaram, fechar a T07 e deixar a T08 pronta para começar.

## O que já existe

O "Resultado" preenchido em cada task desta pasta.

## O que falta

- [ ] `plan-tasks/passo-3/07-e2e-local.md`:
  - uma seção "Resultado" com os 22 cenários, trilho, esperado e observado, e o `error_code` real de cada recusa;
  - estado "feito".
- [ ] "Anotar para a T10" em `07-e2e-local.md`, pronto para a `10-fechamento.md` usar:
  - os códigos reais e as correções do `_traduzir` (T07.6);
  - o comportamento dos cenários 6, 11 e 20, que vai para "Decisões de implementação" do `progresso.md`;
  - o teclado e o colar (T07.7);
  - o cenário 22 (T07.10);
  - se o reinício do Auth zera o limite de e-mails.
- [ ] `plan-tasks/passo-3/09-e2e-remoto.md`: levar o que o local não respondeu e o remoto pode responder diferente (usuário sem `identities` no cadastro repetido, tempo e destino dos e-mails).
- [ ] `plan-tasks/passo-3/README.md`: T07 "feito".
- [ ] Esta pasta: todas as tasks "feito" no [README](README.md).
- [ ] Se o Gboard do celular ficou em modo de teclado físico, avisar o Thiago de como voltar (T07.7).
- [ ] As três suítes SQL, `flutter test` e `dart analyze` passam; `git status` limpo depois do commit.

## Pronto quando

A T07 está "feito" no README do passo 3, cada cenário tem resultado anotado, e a T08 pode começar sem reler esta pasta.

## Commit

`Registra a validação local da autenticação`
