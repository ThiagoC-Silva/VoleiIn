# T07.1 — Atualizar o roteiro da T07 com as decisões

**Estado:** feito · **Depende de:** —

## Objetivo

Deixar [`07-e2e-local.md`](../passo-3/07-e2e-local.md) de acordo com o estado de 2026-10-23 e com as decisões do [README](README.md) antes de escrever código: documentação antes do código.

## O que já existe

- O roteiro dos 22 cenários, com os dois trilhos (API e celular), refeito em 2026-10-20.
- A nota de 2026-10-22 sobre o Gboard no emulador.

## O que falta

- [x] **Preparação**:
  - trocar os `--dart-define=…` avulsos por `--dart-define-from-file=dart_defines.json`, como no `CLAUDE.md` da raiz, com `SUPABASE_URL` no IP atual (`hostname -I`);
  - tirar "não há emulador nesta máquina": há o `voleiin`, que fica de reserva; o trilho de tela roda no celular físico;
  - o trilho de tela é operado pelo Claude pelo `adb` (`input tap`, `uiautomator dump`, `screencap`), com os três pontos que ficam com o Thiago (ver [README](README.md));
  - instalação por `flutter build apk --debug` e `adb install -r`, em vez de `flutter run`, para o app ficar instalado sem um processo preso ao terminal.
- [x] **Orçamento de e-mails**: o local tem `email_sent = 30` por hora e uma rodada inteira do script gasta de 13 a 15. Cabem uma ou duas rodadas por hora; o script ganha `--so <n,…>` para rodar só alguns cenários. Se travar, `docker restart supabase_auth_VoleiIn` (conferir na T07.6 se isso zera o contador).
- [x] **Limite por IP**: uma rodada faz cerca de 17 chamadas de `sign_in_sign_ups` (teto de 30 a cada 5 min). Duas rodadas seguidas podem esbarrar nele.
- [x] **Contas Google**: a divisão entre os dois Gmails e a limpeza entre o 19 e o 18:
  ```sql
  delete from public.dispositivo_push where pessoa_id = '<id>';
  delete from public.pessoa where id = '<id>';
  delete from auth.users where id = '<id>';  -- identities e sessions vão em cascata
  ```
  `pessoa` não tem chave estrangeira para `auth.users` (deliberado), então a ordem importa e nada some sozinho.
- [x] **Cenário 22**: trocar "build de uma máquina sem SHA-1" pelo método da chave descartável (T07.10) e registrar o motivo: `canceled` vira volta silenciosa no `_traduzirGoogle`.
- [x] **Commit**: a seção passa a apontar para as tasks de [`planT07/`](README.md), um commit por task, em vez dos três commits previstos.
- [x] Um link para `plan-tasks/planT07/README.md` no topo do arquivo.

## Resultado

`07-e2e-local.md` ganhou:
- o link para `planT07/` no topo;
- em "Como roda", as opções do script (`--so`, `--com-expiracao`, `--impostor`) e o trilho de tela no celular físico operado pelo Claude, com o emulador `voleiin` de reserva e os três pontos do Thiago;
- a seção "Limites do Auth local" (e-mails por hora e entradas por IP), com o reinício só do contêiner do Auth e o `config.toml` intocado;
- em "Preparação", o `sg docker`, o IP em `app/dart_defines.json`, a conferência de rede por `adb` e a instalação por `flutter build apk --debug` e `adb install -r`;
- a seção "Contas Google", com a divisão dos dois Gmails e o SQL de limpeza;
- o cenário 22 pela chave descartável, com o risco do `canceled`;
- a nota do teclado apontando para a conferência com o dedo na T07.7;
- "Commit" apontando para as tasks.

Conferido no código: `dispositivo_push.pessoa_id`, `_traduzirGoogle` com o `canceled` tratado antes dele em `entrarComGoogle` (`app/lib/dados/auth_repositorio.dart`), `email_sent` e `sign_in_sign_ups` em `supabase/config.toml`, e `br.com.voleiin/.MainActivity`.

O `README.md` do passo 3 continua com a T07 "a fazer". A linha de 2026-10-20 dele ("não há emulador nesta máquina") ficou como está, por ser registro da decisão daquele dia.

## Pronto quando

`07-e2e-local.md` descreve o que vai ser executado, sem instrução desatualizada, e o `README.md` do passo 3 continua com a T07 "a fazer".

## Commit

`Atualiza o roteiro da T07 e o quebra em tasks` — `07-e2e-local.md` e a pasta `plan-tasks/planT07/`.
