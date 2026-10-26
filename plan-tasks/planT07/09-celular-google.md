# T07.9 — Celular: cenários do Google (17 a 21)

**Estado:** feito · **Depende de:** T07.8

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
- [x] **17** — "Entrar com Google" → seletor → Gmail de teste → início direto. `pessoa.nome` é o nome da conta Google, `avatar_url` é nulo, e nenhum e-mail chega.
- [x] **20** — "Trocar e-mail" para `diana.<epoch>@exemplo.com` → código no Mailpit → snackbar. "Sair", "Entrar com Google" com o mesmo Gmail: **anotar** se cai na mesma conta (mesmo `pessoa.id`, e-mail novo) ou cria outra.
- [x] **21** — "Esqueci a senha" com o e-mail atual da Diana → código → senha nova. Depois, entrar com e-mail e senha também funciona.

**Gmail do Thiago — impostor, depois Bruno**
- [x] **19** — `autenticacao_api.sh --impostor <gmail>`: cadastro pendente com nome "Impostor". No app, "Entrar com Google" com esse Gmail. Esperado:
  - mesmo `auth.users.id` do cadastro pendente, agora confirmado;
  - `encrypted_password` nulo;
  - `pessoa.nome` com o nome do Google, não "Impostor";
  - a senha do impostor por `curl` dá `invalid_credentials`.
  - **Se a senha do impostor entrar, parar**: contraria a RN21, e a decisão do cadastro com senha é reaberta antes de seguir.
- [x] Limpeza da conta pelo SQL de `07-e2e-local.md`.
- [x] **18** — Bruno cria conta com senha no app com esse Gmail, confirma pelo código do Mailpit, sai e entra pelo Google. Esperado: mesmo `pessoa.id`, e a senha continua entrando (por `curl`).

Telas de consentimento ou verificação do Google que aparecerem: o Claude para e o Thiago decide.

## Resultado

Executado em 2026-10-26 no Motorola Edge 60 Pro, máquina em `192.168.2.110`, operado pelo `adb`, com o APK reconstruído do `main`. Os dois Gmails estavam sem conta local antes de começar. Como os dois estão na lista de usuários de teste, a distribuição entre Diana e impostor/Bruno foi arbitrária. Os endereços não entram aqui; a Diana trocou para `diana.<epoch>@exemplo.com`.

| # | O que a tela mostrou | Servidor |
| --- | --- | --- |
| 17 | "Entrar com Google" → seletor com as duas contas → **tela de consentimento do Google** ("Permitir login com o Google no app VoleiIn", nome, e-mail e foto) → "Concordar e compartilhar" → início com "Olá, <nome da conta Google>" e o Gmail | usuário confirmado, **sem** senha, identidade `google`; `pessoa.nome` = `full_name` do Google, mesmo id; `avatar_url` nulo, embora a identidade traga a foto; nenhum e-mail |
| 20 | "Trocar e-mail" → endereço novo → código → snackbar "E-mail trocado. Os outros aparelhos foram desconectados." → início com o e-mail novo. "Sair" → "Entrar com Google" com o mesmo Gmail → início, **mesma conta**, com o e-mail **novo**, sem consentimento | código só no novo e aviso no Gmail; `auth.users.email` trocado. A identidade `google` continua com o Gmail e uma identidade `email` nova aparece com o endereço novo. O segundo login pelo Google acha a conta pela identidade `google`: mesmo `pessoa.id`, nenhum usuário novo, `auth.users.email` não volta ao Gmail, nenhum e-mail |
| 21 | A1 com o e-mail novo → "Esqueci a senha" → A4 com o e-mail já digitado → código e senha nova → "Senha trocada. Os outros aparelhos foram desconectados." e início. "Sair" e A1 com e-mail e senha nova → início | código e aviso de senha trocada no endereço novo; a senha nova entra também por `curl`, com o mesmo id. A conta fica com Google e senha |
| 19 | `--impostor`: pendente com nome "Impostor", senha, identidade `email` e sem `pessoa`. No app, "Entrar com Google" com o mesmo Gmail → consentimento (primeiro login dessa conta) → início com "Olá, <nome da conta Google>" | **mesmo** `auth.users.id` do pendente, agora confirmado; `encrypted_password` nulo; `pessoa.nome` do Google, não "Impostor"; a identidade `email` do impostor some e fica só a `google`; a senha do impostor por `curl` dá `invalid_credentials`. **RN21 confirmada** |
| — | Limpeza pelo SQL de `07-e2e-local.md`, depois de "Sair" no app | `pessoa` e `auth.users` apagados; nenhum usuário nem identidade restante para o Gmail |
| 18 | A2 com "Bruno", o Gmail e senha → A3 → código → "Olá, Bruno". "Sair" → "Entrar com Google" com o mesmo Gmail → início com "Olá, Bruno", sem consentimento | mesmo `pessoa.id`; o nome continua "Bruno", não o do Google; identidades `email` e `google`; a senha continua entrando por `curl`; nenhum e-mail no login pelo Google |

**Nenhuma correção.** Os cinco cenários deram o esperado.

**Observado, sem correção:**
- **Consentimento do Google** no primeiro login de cada conta Google no VoleiIn. Ele aparece por cima da A1 e mostra o ícone do Flutter, porque o ícone próprio fica para o passo 10. Não volta nos logins seguintes da mesma conta. O texto diz que o Google compartilha a foto, mas o app não grava `avatar_url`.
- **Cenário 20:** o login pelo Google segue a identidade, não o e-mail atual. Quem trocou o e-mail continua entrando pelo Google com o Gmail antigo, cai na mesma conta e mantém o e-mail novo. Vai para "Decisões de implementação" do `progresso.md` na T07.11.
- **Nome no vínculo:** no 19, o nome do Google substitui o do cadastro pendente. No 18, a conta já confirmada mantém o nome dela ("Bruno").
- Na A3 e na troca de e-mail, as seis casas preenchidas pelo `adb` não confirmam sozinhas: é preciso tocar em "Confirmar". É o mesmo que na T07.8.

**Para a T07.10 (operação pelo `adb`):**
- O campo "E-mail novo" da troca de e-mail aparece no dump como `EditText` com `NAF="true"`, sem `content-desc`, e é achado pelo `hint`.
- Na A4, com o teclado aberto, "Salvar nova senha" fica fora do dump. Um "voltar" com `mInputShown=true` fecha o teclado sem sair do app, e o botão aparece.
- No zsh, URL com `?` precisa de aspas, senão o `curl` nem roda.
- O celular voltou ao `adb devices` sozinho, pelo mDNS, assim que a depuração sem fio foi religada.

## Pronto quando

Os cinco cenários rodaram, o 19 confirmou a RN21, e o comportamento do 20 está anotado.

## Commit

Um por correção que algum cenário exigir, e um último com o registro da task. Nenhuma correção; registro: `Registra a rodada do Google no celular`.
