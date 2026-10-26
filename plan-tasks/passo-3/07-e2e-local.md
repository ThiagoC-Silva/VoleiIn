# T07 — Validação ponta a ponta no Supabase local

**Estado:** feito · **Depende de:** T02, T03, T05, T06, T11, T12

Execução quebrada em tasks, uma por vez: [`plan-tasks/planT07/`](../planT07/README.md). Este arquivo guarda o roteiro; lá ficam a ordem, as decisões de 2026-10-23 e o resultado de cada rodada.

## Objetivo

Provar, contra o Supabase local, o que as asserções SQL e os testes de widget não alcançam:
- o caminho real do Supabase Auth até os gatilhos;
- os códigos de erro reais;
- a queda das outras sessões;
- a vinculação com o Google.

## Roteiro refeito em 2026-10-20 — senha e Google

O roteiro anterior era da entrada por código. Saem os cenários dela: o e-mail `codigo_acesso.html` na segunda entrada, o `otp_disabled` e o antigo cenário 11 (retorno de cadastro não confirmado à entrada por código). Entram cadastro e entrada com senha, redefinição de senha e Google. Ver as decisões no [README](README.md).

## Como roda (decidido em 2026-10-20)

Dois trilhos:
- **Servidor, por script versionado**: `supabase/testes/autenticacao_api.sh`.
  - Bash com `curl` e `jq`.
  - Fala com a API do Auth: `/signup`, `/token?grant_type=password`, `/verify`, `/recover`, `/resend`, `/user`, `/logout?scope=others` e `/token?grant_type=refresh_token`.
  - Lê o código pela API do Mailpit: `/api/v1/search` e `/api/v1/message/{id}`.
  - Saída como a das suítes SQL: `FALHOU: …` e saída ≠ 0, ou `SUCESSO: N cenários`.
  - E-mails únicos por rodada (`carla.<epoch>@exemplo.com`).
  - Parâmetros por ambiente (`AUTH_URL`, `CHAVE`, `MAILPIT_URL`, `PSQL`, `EMAIL_BASE`), para ser reaproveitado na T09: sem `MAILPIT_URL`, pede o código no terminal; sem `PSQL`, pula as conferências de banco.
  - Opções: `--so <n,…>` roda só os cenários dados; `--com-expiracao` liga o de cinco minutos; `--impostor <gmail>` só cria o cadastro pendente do cenário 19, fora da contagem.
  - Cobre a parte de servidor dos cenários marcados "API" abaixo, mais e-mail inválido e o conteúdo dos cinco e-mails da T02.
  - A linha de comando entra em `supabase/CLAUDE.md`.
- **Tela, no celular físico** (Motorola Edge 60 Pro), por depuração sem fio, como no `CLAUDE.md` da raiz. O emulador `voleiin` (Android 35, imagem `google_apis_playstore`) fica de reserva.
  - O Claude opera o aparelho pelo `adb`: toques com `input tap`, elementos por `uiautomator dump`, conferência por `screencap`. Os códigos saem do Mailpit.
  - Ficam com o Thiago:
    - a conferência do teclado das seis casas e do colar, com o dedo, antes de qualquer tecla injetada pelo `adb`;
    - adicionar ao aparelho as contas Google que faltarem;
    - telas de consentimento ou verificação do Google, se aparecerem.
  - Cobre os cenários marcados "celular", inclusive todos os do Google: o ID token exige conta Google real e o seletor do Android.

`over_request_rate_limit` e o limite de entradas por IP (`sign_in_sign_ups`) ficam sem exercitar: pediriam mais de 30 tentativas e travariam a rodada por cinco minutos.

## Limites do Auth local

O `config.toml` não muda para caber nos testes: tem de seguir igual ao remoto.

- **E-mails**: sem limite no local. `email_sent = 30` exige SMTP próprio, e sem ele o CLI sobe o Auth com `GOTRUE_RATE_LIMIT_EMAIL_SENT=360000` (já anotado na T03): na T07.6, 38 e-mails numa hora chegaram todos ao Mailpit. Uma rodada inteira gasta 16, e o teto de 30 por hora só se verifica no remoto, na T09.
- **Por IP**: uma rodada faz cerca de 17 chamadas contadas em `sign_in_sign_ups`, com teto de 30 a cada cinco minutos. Duas rodadas seguidas podem esbarrar nele; entre uma e outra, esperar cinco minutos.

## Preparação

Até a sessão ser reaberta com o grupo `docker`, os comandos do Docker rodam com `sg docker -c '…'` (`docs/progresso.md`, passo 1).

- `supabase start` e `supabase status` para pegar a chave pública.
- `supabase/.env` com o segredo do Google (T11).
- Celular na mesma rede:
  - `hostname -I | awk '{print $1}'` para o IP de agora, e `SUPABASE_URL=http://<ip>:54321` em `app/dart_defines.json`, como no `CLAUDE.md` da raiz;
  - `http://<ip>:54321/auth/v1/health` abre no navegador do celular (aberto por `adb shell am start -a android.intent.action.VIEW -d …` e conferido por `screencap`); se não abrir, é a rede, não o app.
- Instalação por build e `adb install`, sem `flutter run`, para o app ficar instalado sem um processo preso ao terminal. A partir de `app/`:
  ```
  flutter build apk --debug --dart-define-from-file=dart_defines.json
  adb -s <id> install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s <id> shell am start -n br.com.voleiin/.MainActivity
  ```
- SHA-1 da chave de debug desta máquina cadastrado no cliente Android (T11).
- Os dois Gmails da lista de usuários de teste do Google (T11) adicionados ao aparelho; os endereços são pedidos na hora e não entram em arquivo versionado (ver "Contas Google").
- Mailpit em `http://127.0.0.1:54324` para ler os códigos; no celular, em `http://<ip>:54324`.
- Conferências no banco: `sg docker -c 'docker exec -it supabase_db_VoleiIn psql -U postgres'`.

## Contas Google

São dois Gmails, ambos na lista de usuários de teste:
- **Gmail de teste — Diana**: cenários 17, 20 e 21.
- **Gmail do Thiago**: primeiro o impostor (19); depois de apagada a conta, o Bruno (18).

Antes de usar cada Gmail, conferir por `psql` que ele não tem conta local. Para apagar uma conta, entre o 19 e o 18 ou numa sobra de rodada anterior:

```sql
delete from public.dispositivo_push where pessoa_id = '<id>';
delete from public.pessoa where id = '<id>';
delete from auth.users where id = '<id>';  -- identities e sessions vão em cascata
```

`pessoa` não tem chave estrangeira para `auth.users`, e isso é deliberado (`docs/stack.md`, Autenticação). Por isso a ordem importa e nada some sozinho: apagar só `auth.users` deixa `pessoa` órfã.

## Roteiro

| # | Cenário | Trilho | Esperado |
| --- | --- | --- | --- |
| 1 | Carla cria conta com senha | API, celular | Chega `confirmacao.html` com o código. Antes de confirmar, não há `pessoa`. Ao confirmar, cai no início com "Olá, Carla", e `pessoa` tem a linha com o id de `auth.users` |
| 2 | Carla sai e entra com e-mail e senha | API, celular | Entra sem nenhum e-mail enviado |
| 3 | Senha errada | API, celular | `invalid_credentials`; mensagem; continua na etapa |
| 4 | Cadastro com senha de 7 caracteres (forçado via curl) | API | `weak_password` |
| 5 | Cadastro com e-mail que já tem conta | API, celular | `user_already_exists`, como na sonda da T02, ou usuário devolvido sem `identities`; nenhum e-mail; a tela diz que o e-mail já tem conta |
| 6 | Cadastro não confirmado, depois entrar com a senha | API, celular | `email_not_confirmed`; o código é reenviado; confirmar entra. Anotar também: um segundo `signUp` com outra senha antes de confirmar — qual senha vale depois |
| 7 | Código errado, código depois de 5 min (`--com-expiracao`) e código usado duas vezes | API | Os três recusados; anotar o código de erro de cada um |
| 8 | Reenvio antes de 60 s | API | `over_email_send_rate_limit` |
| 9 | Bruno esquece a senha, com uma segunda sessão aberta (login por curl) e linhas em `dispositivo_push` (inseridas à mão) | API, celular | Chega `redefinicao_senha.html`. Ao concluir: a segunda sessão perde a renovação do token, as linhas somem, chega `aviso_troca_senha.html`, a senha antiga é recusada e a nova entra |
| 10 | Redefinição para e-mail sem conta | API | Resposta igual à de e-mail com conta; nenhum e-mail |
| 11 | Senha nova igual à atual | API | `same_password`; anotar se a sessão criada na conferência do código fica de pé |
| 12 | Troca de senha sem código, por sessão com mais de 24 h (`created_at` envelhecido em `auth.sessions` pelo `psql`) | API | `reauthentication_needed` (`secure_password_change`) |
| 13 | Carla troca para `carla2@…` | API, celular | Código só no endereço novo; aviso no antigo; o app continua logado com o e-mail novo |
| 14 | Carla com segunda sessão aberta ao trocar o e-mail | API | A segunda sessão perde a renovação do token |
| 15 | Carla com linhas em `dispositivo_push` ao trocar o e-mail | API | As linhas somem só depois da confirmação, não no pedido |
| 16 | Troca para o e-mail do Bruno, que já tem conta | API, celular | Recusada com a mensagem de e-mail de outra conta (`email_exists`) |
| 17 | Diana entra pelo Google pela primeira vez | celular | Entra direto; `pessoa.nome` é o nome da conta Google; `avatar_url` nulo; nenhum e-mail enviado |
| 18 | Bruno, que tem conta com senha, entra pelo Google com o mesmo Gmail | celular | Mesmo `pessoa.id` de antes; a senha continua valendo |
| 19 | Impostor: cadastro com senha (curl) no Gmail de teste, sem confirmar; depois o dono entra pelo Google com esse Gmail | API, celular | `encrypted_password` nulo; `pessoa` nasce com o nome do Google, não o do cadastro; a senha do impostor é recusada |
| 20 | Diana, só com Google, troca o e-mail da conta | celular | Código no endereço novo; entrar pelo Google continua caindo na mesma conta (anotar) |
| 21 | Diana usa "Esqueci a senha" | celular | Passa a entrar também com e-mail e senha |
| 22 | APK assinado com chave sem SHA-1 cadastrado: o de debug reassinado com uma keystore descartável criada no scratchpad, sem tocar em `build.gradle.kts` nem em `~/.android/debug.keystore` | celular | A tela diz que a entrada pelo Google não está configurada neste aparelho. Anotar o código que o `google_sign_in` devolve, para a mensagem da tela e o `CLAUDE.md`. O risco: `_traduzirGoogle` trata `canceled` como seletor fechado e volta sem mensagem; se a chave sem cadastro chegar como `canceled`, o toque não faz nada e a pessoa fica sem pista |

## Resultado

Rodado de 2026-10-23 a 2026-10-26, Auth v2.197.0, no trilho da API (`autenticacao_api.sh --com-expiracao`: `SUCESSO: 17 cenários`, modelos 5 de 5, 6 min 45 s, 16 e-mails) e no celular (Motorola Edge 60 Pro, Android 16). O detalhe de cada rodada está no "Resultado" das tasks de [`planT07/`](../planT07/README.md): API em T07.2 a T07.6, celular em T07.7 a T07.10.

| # | Trilho | Observado | Contra o esperado | `error_code` |
| --- | --- | --- | --- | --- |
| 1 | API, celular | `/signup` 200 sem sessão e sem `pessoa`; o código confirma, e `pessoa` nasce com o id de `auth.users` e o nome. No celular, A2 → A3 → "Olá, Carla" | igual | — |
| 2 | API, celular | Entra com 200; nenhum e-mail em 5 s | igual | — |
| 3 | API, celular | 400; "E-mail ou senha incorretos." acima do "Entrar", a A1 continua com os campos | igual | `invalid_credentials` |
| 4 | API | 422 com `reasons: ["length"]`; `auth.users` sem a linha | igual | `weak_password` |
| 5 | API, celular | 422 e nenhum e-mail; a A2 mostra "Esse e-mail já tem conta. Entre com a senha ou pelo Google." | igual; o local não esconde a conta com usuário sem `identities` | `user_already_exists` |
| 6 | API, celular | Entrada sem confirmar: 400. Na A1, dentro dos 60 s, o reenvio recusado é engolido e o código anterior vale. Depois dos 60 s, chega código novo, o antigo é recusado, e o novo entra. **Cadastro refeito** antes do código: 429 dentro dos 60 s; depois, 200 com o mesmo id e código novo, mas ficam a senha e o nome do **primeiro** pedido, inclusive o de um impostor | igual no esperado; o cadastro refeito abriu uma tomada de conta, decidida em 2026-10-26 e corrigida na [T13](13-cadastro-refeito.md) | `email_not_confirmed`, `over_email_send_rate_limit` |
| 7 | API | Código errado, repetido e vencido (301 s): 403 nos três | igual | `otp_expired` nos três |
| 8 | API | 429 no reenvio antes de 60 s. O limite é por tipo de e-mail, não por usuário: o `/recover` logo depois do cadastro passa | igual | `over_email_send_rate_limit` |
| 9 | API, celular | A renovação das outras sessões é recusada, as linhas de `dispositivo_push` somem e chega o aviso de senha trocada. A senha antiga é recusada e a nova entra. A troca de senha **sozinha** já derruba as outras sessões, antes do `signOut(others)`. No celular, pela A1 e pela sessão ("Trocar senha"), o snackbar "Senha trocada. Os outros aparelhos foram desconectados." e o início | igual | `refresh_token_not_found`, `invalid_credentials` |
| 10 | API | 200 `{}`, igual ao de e-mail com conta; nenhum e-mail | igual | — |
| 11 | API, celular | 422. A sessão criada no `/verify` **continua de pé** e não chega aviso. No app, a segunda tentativa dava "Código inválido ou vencido", porque o código já tinha sido gasto: corrigido (a A4 confere o código uma vez só). "Voltar" na A4 com a senha não trocada leva ao início logado | igual no servidor; o app foi corrigido | `same_password` |
| 12 | API | 400 com a sessão envelhecida 25 h. Pelo caminho do app (código, sessão nova, `PUT /user`) passa | igual | `reauthentication_needed` |
| 13 | API, celular | O código chega só no endereço novo, e o aviso chega no antigo. O `/verify` de troca devolve **sessão nova**, e é ela que segue logada com o e-mail novo. No celular, o snackbar "E-mail trocado. Os outros aparelhos foram desconectados." | igual | — |
| 14 | API | A troca sozinha **não** derruba a segunda sessão; o `signOut(others)` derruba | igual; o `signOut(others)` da troca de e-mail é indispensável | `refresh_token_not_found` |
| 15 | API | As linhas continuam depois do pedido e somem na confirmação | igual | — |
| 16 | API, celular | 422 e nenhum e-mail; "Esse e-mail já pertence a outra conta.", e a tela fica na etapa do e-mail | igual | `email_exists` |
| 17 | celular | Tela de consentimento do Google no primeiro login, depois o início com o nome da conta Google; `avatar_url` nulo; nenhum e-mail | igual | — |
| 18 | celular | Mesmo `pessoa.id`; o nome continua o do cadastro ("Bruno"); a senha continua entrando | igual | — |
| 19 | API, celular | Mesmo `auth.users.id`, agora confirmado; `encrypted_password` nulo; a identidade `email` do impostor some; `pessoa.nome` vem do Google; a senha do impostor é recusada. **RN21 confirmada** | igual | `invalid_credentials` |
| 20 | celular | Troca concluída. O login seguinte pelo Google com o Gmail antigo cai na **mesma conta**, que mantém o e-mail novo: o serviço acha a conta pela identidade `google`, não pelo e-mail atual | o comportamento anotado | — |
| 21 | celular | Código e aviso no e-mail novo; depois, a conta entra pelo Google e por senha | igual | — |
| 22 | celular | Antes da correção, a A1 voltava sem mensagem. Depois: "Não foi possível entrar com o Google. Entre com e-mail e senha." | **divergiu**: o esperado era "não está configurada neste aparelho"; o Thiago decidiu pela genérica (T07.10) | `canceled`, com `description` `[16] Account reauth failed.` |
| e-mail inválido | API | `carla@`: 400 | — | `validation_failed` |

**Correções da T07**, cada uma com teste e conferida de novo no celular:
- `Devolve o foco às casas do código depois da chamada` (T07.8);
- `Confere o código da redefinição uma vez só` (T07.8, cenário 11);
- `Trata a chave sem cadastro na entrada pelo Google` (T07.10, cenário 22).

## Anotar para a T10

Pronto para a [`10-fechamento.md`](10-fechamento.md) levar ao `progresso.md`:

- **Códigos reais**: a tabela acima e a da [T07.6](../planT07/06-rodada-completa.md). Nenhum código observado caiu na mensagem genérica sem motivo registrado, e o `_traduzir` não mudou. `email_address_invalid`, `over_request_rate_limit` e o usuário sem `identities` ficam no `_traduzir`, porque o remoto pode usá-los (T09). A única mudança de tradução foi a do Google: `traduzirGoogle` só silencia o `canceled` cuja `description` contém "Cancelled by user" (T07.10).
- **Decisões de implementação**, pelo comportamento observado:
  - cenário 6: na entrada de cadastro pendente, o reenvio recusado nos 60 s é engolido, e o código anterior continua valendo;
  - cenário 6, cadastro refeito: o serviço fica com a senha e o nome do primeiro pedido. Decisão de produto de 2026-10-26: a A3 aberta pela A2 grava, depois do código, a senha e o nome digitados ([T13](13-cadastro-refeito.md); `docs/prd.md`, RN21; `docs/stack.md`, Autenticação);
  - cenário 11: a sessão nasce na conferência do código de redefinição e fica de pé depois de `same_password`. Por isso a A4 confere o código uma vez só e, nas tentativas seguintes, só grava a senha. "Voltar" na A4 leva ao início logado, sem brecha, porque a posse do e-mail já foi provada;
  - cenário 20: o login pelo Google segue a identidade `google`, não o e-mail atual. Quem trocou o e-mail continua entrando pelo Google com o Gmail antigo e cai na mesma conta, com o e-mail novo;
  - a troca de senha derruba as outras sessões sozinha, e o `signOut(others)` do `salvarSenhaNova` fica redundante, sem prejuízo; na troca de e-mail, é ele que as derruba.
- **Teclado e colar** (T07.7): no celular, o teclado numérico abre inteiro na A3 e ao tocar nas casas, e o código colado preenche as seis. O Gboard não entrou em modo de teclado físico depois das teclas injetadas pelo `adb` (T07.8); conferido de novo na T07.11, `show_ime_with_hard_keyboard` continua `0`, o valor de antes. Se um dia entrar: Configurações → Sistema → Idiomas e entrada → Teclado físico → "Usar teclado na tela".
- **Cenário 22** (T07.10): a chave sem SHA-1 cadastrado chega ao app como `canceled`, igual ao seletor fechado. A tela mostra a falha genérica, e o sintoma está no `CLAUDE.md` da raiz, com o aviso de esperar uns dez minutos depois de cadastrar o SHA-1.
- **E-mails no local**: sem limite. Sem SMTP próprio, o CLI sobe o Auth com `GOTRUE_RATE_LIMIT_EMAIL_SENT=360000`, e `email_sent = 30` só vale no remoto (T07.6).

## Pronto quando

Os 22 cenários rodaram e o resultado de cada um está anotado, com as divergências corrigidas ou registradas.

## Commit

Um commit por task de [`planT07/`](../planT07/README.md), com a mensagem dada em cada uma, mais um por correção que algum cenário exigir. A T07.11 registra os resultados e fecha a T07.
