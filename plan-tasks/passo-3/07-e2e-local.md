# T07 — Validação ponta a ponta no Supabase local

**Estado:** a fazer · **Depende de:** T02, T03, T05, T06

## Objetivo

Provar, contra o Supabase local, o que as asserções SQL e os testes de widget não alcançam: o caminho real do Supabase Auth até o gatilho, os códigos de erro reais e a queda das outras sessões.

## Como roda (decidido em 2026-10-20)

Dois trilhos:
- **Servidor, por script versionado** — `supabase/testes/autenticacao_api.sh`, em bash com `curl` e `jq`, falando com a API do Auth (`/otp`, `/verify`, `/user`, `/logout?scope=others`, `/token?grant_type=refresh_token`) e lendo o código pela API do Mailpit (`/api/v1/search`, `/api/v1/message/{id}`). Saída como a das suítes SQL: `FALHOU: …` e saída ≠ 0, ou `SUCESSO: N cenários`. E-mails únicos por rodada (`carla.<epoch>@exemplo.com`). Parâmetros por ambiente (`AUTH_URL`, `CHAVE`, `MAILPIT_URL`, `PSQL`, `EMAIL_BASE`), para ser reaproveitado na T09: sem `MAILPIT_URL` pede o código no terminal; sem `PSQL` pula as conferências de banco. O cenário 4 (cinco minutos) só roda com `--com-expiracao`. Cobre 3, 4, 5, 6, 8, 9, 10 e 11, mais `otp_disabled`, e-mail inválido e o conteúdo dos quatro e-mails da T02. A linha de comando entra em `supabase/CLAUDE.md`.
- **Tela, no celular físico** — não há emulador nesta máquina. Depuração sem fio, como no `CLAUDE.md` da raiz; o usuário opera, e os códigos saem do Mailpit. Cobre 1, 2, 3, 7 e a mensagem do 10.

`over_request_rate_limit` fica sem exercitar: pediria mais de 30 verificações por IP e travaria a rodada por cinco minutos.

## Preparação

- `supabase start` e `supabase status` para pegar a chave pública.
- Celular na mesma rede; `hostname -I` para o IP; `http://<ip>:54321` abre no navegador do celular; o app com `--dart-define=SUPABASE_URL=http://<ip>:54321`.
- Mailpit aberto em `http://127.0.0.1:54324` para ler os códigos.
- Conferências no banco: `docker exec -it supabase_db_VoleiIn psql -U postgres`.

## Roteiro

| # | Cenário | Esperado |
| --- | --- | --- |
| 1 | Carla, e-mail sem conta | Pede o nome; chega `confirmacao.html` com o código; antes de confirmar, não há `pessoa`; ao confirmar, cai no início com "Olá, Carla"; `pessoa` tem a linha com o id de `auth.users` |
| 2 | Carla sai e entra de novo | Vai direto ao código, sem pedir nome; chega `codigo_acesso.html` |
| 3 | Código errado | Mensagem de código inválido; continua na etapa |
| 4 | Código depois de 5 min | Recusado (`otp_expired`) |
| 5 | Mesmo código usado duas vezes | A segunda vez é recusada |
| 6 | Reenvio antes de 60 s (forçado via curl) | Servidor recusa (`over_email_send_rate_limit`) |
| 7 | Carla troca para `carla2@…` | Código só no endereço novo; aviso no antigo; o app continua logado com o e-mail novo |
| 8 | Carla com segunda sessão aberta (outro emulador ou login por curl) ao trocar o e-mail | A segunda sessão perde a renovação do token e volta para entrar |
| 9 | Carla com linhas em `dispositivo_push` (inserir à mão) ao trocar o e-mail | As linhas somem só depois da confirmação, não no pedido |
| 10 | Troca para o e-mail do Bruno, que já tem conta | Recusada com a mensagem de e-mail de outra conta (`email_exists`) |
| 11 | Pedir o código de conta nova e nunca confirmar | Existe `auth.users` sem `email_confirmed_at` e **não** existe `pessoa`. Anotar também o que acontece quando esse e-mail volta à tela de entrar: `pedirCodigo` recebe `otp_disabled` (pede o nome de novo) ou recebe código direto; e se um segundo `criarConta` troca o nome dos metadados |

## Anotar para a T10

- O código real que o Auth devolve em cada erro (ajustar `_traduzir` na T05 se diferir).
- Cenário 11: decidido em 2026-10-20 que o perfil só nasce na confirmação (reabertura da T03). Se o cadastro não confirmado ainda criar `pessoa`, é defeito da T02/T03, não decisão aberta. O comportamento do retorno de um e-mail não confirmado vai para "Decisões de implementação" no `progresso.md`.

## Pronto quando

Os onze cenários rodaram e o resultado de cada um está anotado, com as divergências corrigidas ou registradas.

## Commit

1. `Cria o roteiro de autenticação pela API do Auth` — o script e a linha em `supabase/CLAUDE.md`.
2. Um commit por correção que algum cenário exigir.
3. `Registra a validação local da autenticação` — os resultados nos arquivos de `plan-tasks/passo-3/`.
