# T07.9 — Celular: cenários do Google (17 a 21)

**Estado:** a fazer · **Depende de:** T07.8

## Objetivo

Provar a entrada pelo Google com conta real e o seletor do Android: perfil com o nome do Google, mesmo e-mail é a mesma conta, e o cadastro de um impostor não sobrevive à vinculação (RN21).

## O que já existe

- O provedor Google ligado no local (`[auth.external.google]`, `skip_nonce_check = true`) e o segredo em `supabase/.env`.
- Os dois Gmails na lista de usuários de teste e adicionados ao aparelho (T07.7).
- `--impostor` no script (T07.5) e o SQL de limpeza em `07-e2e-local.md` (T07.1).
- O que a T07.8 aprendeu sobre operar o app pelo `adb` (espera antes de digitar, como limpar campo, o "voltar" que sai do app, nós que faltam no dump): seção "Para a T07.9" de [08-celular-senha.md](08-celular-senha.md).

## O que falta

Os endereços são pedidos ao Thiago na hora e não entram em arquivo versionado. Antes de cada Gmail, conferir por `psql` que ele não tem conta local; se tiver, limpar.

**Gmail de teste — Diana**
- [ ] **17** — "Entrar com Google" → seletor → Gmail de teste → início direto. `pessoa.nome` é o nome da conta Google, `avatar_url` é nulo, e nenhum e-mail chega.
- [ ] **20** — "Trocar e-mail" para `diana.<epoch>@exemplo.com` → código no Mailpit → snackbar. "Sair", "Entrar com Google" com o mesmo Gmail: **anotar** se cai na mesma conta (mesmo `pessoa.id`, e-mail novo) ou cria outra.
- [ ] **21** — "Esqueci a senha" com o e-mail atual da Diana → código → senha nova. Depois, entrar com e-mail e senha também funciona.

**Gmail do Thiago — impostor, depois Bruno**
- [ ] **19** — `autenticacao_api.sh --impostor <gmail>`: cadastro pendente com nome "Impostor". No app, "Entrar com Google" com esse Gmail. Esperado:
  - mesmo `auth.users.id` do cadastro pendente, agora confirmado;
  - `encrypted_password` nulo;
  - `pessoa.nome` com o nome do Google, não "Impostor";
  - a senha do impostor por `curl` dá `invalid_credentials`.
  - **Se a senha do impostor entrar, parar**: contraria a RN21, e a decisão do cadastro com senha é reaberta antes de seguir.
- [ ] Limpeza da conta pelo SQL de `07-e2e-local.md`.
- [ ] **18** — Bruno cria conta com senha no app com esse Gmail, confirma pelo código do Mailpit, sai e entra pelo Google. Esperado: mesmo `pessoa.id`, e a senha continua entrando (por `curl`).

Telas de consentimento ou verificação do Google que aparecerem: o Claude para e o Thiago decide.

## Resultado

_Preenchido na execução, em especial o 19 e o 20._

## Pronto quando

Os cinco cenários rodaram, o 19 confirmou a RN21, e o comportamento do 20 está anotado.

## Commit

Um por correção que algum cenário exigir, e um último com o registro da task.
