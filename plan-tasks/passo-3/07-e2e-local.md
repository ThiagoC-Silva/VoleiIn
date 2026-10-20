# T07 — Validação ponta a ponta no Supabase local

**Estado:** a fazer · **Depende de:** T02, T03, T05, T06, T11, T12

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
  - O cenário da expiração (cinco minutos) só roda com `--com-expiracao`.
  - Cobre a parte de servidor dos cenários marcados "API" abaixo, mais e-mail inválido e o conteúdo dos cinco e-mails da T02.
  - A linha de comando entra em `supabase/CLAUDE.md`.
- **Tela, no celular físico**: não há emulador nesta máquina.
  - Depuração sem fio, como no `CLAUDE.md` da raiz; o usuário opera, e os códigos saem do Mailpit.
  - Cobre os cenários marcados "celular", inclusive todos os do Google: o ID token exige conta Google real e o seletor do Android.

`over_request_rate_limit` e o limite de entradas por IP (`sign_in_sign_ups`) ficam sem exercitar: pediriam mais de 30 tentativas e travariam a rodada por cinco minutos.

## Preparação

- `supabase start` e `supabase status` para pegar a chave pública.
- `supabase/.env` com o segredo do Google (T11).
- Celular na mesma rede:
  - `hostname -I` para o IP;
  - `http://<ip>:54321` abre no navegador do celular;
  - o app com `--dart-define=SUPABASE_URL=http://<ip>:54321` e `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
- SHA-1 da chave de debug desta máquina cadastrado no cliente Android (T11).
- Uma conta Google de teste à mão: um Gmail que ainda não tenha conta no VoleiIn local.
- Mailpit aberto em `http://127.0.0.1:54324` para ler os códigos.
- Conferências no banco: `docker exec -it supabase_db_VoleiIn psql -U postgres`.

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
| 22 | Build de uma máquina sem SHA-1 cadastrado | celular | Anotar o erro que o `google_sign_in` devolve, para a mensagem da tela e o `CLAUDE.md` |

## Anotar para a T10

- O código real que o Auth devolve em cada erro. Ajustar `_traduzir` (T05 e T12) se diferir.
- Cenários 6, 11 e 20: o comportamento observado vai para "Decisões de implementação" no `progresso.md`.
- Cenário 19: se a senha do impostor sobreviver à vinculação, isso contraria a RN21 e é a premissa do cadastro confirmado por código (`docs/prd.md`, decisão Cadastro com senha). Parar e reabrir a decisão antes de seguir.
- Se um cadastro não confirmado criar `pessoa`, é defeito da T02/T03, não decisão aberta.

## Pronto quando

Os 22 cenários rodaram e o resultado de cada um está anotado, com as divergências corrigidas ou registradas.

## Commit

1. `Cria o roteiro de autenticação pela API do Auth` — o script e a linha em `supabase/CLAUDE.md`.
2. Um commit por correção que algum cenário exigir.
3. `Registra a validação local da autenticação` — os resultados nos arquivos de `plan-tasks/passo-3/`.
