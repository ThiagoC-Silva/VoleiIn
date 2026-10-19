# T07 — Validação ponta a ponta no Supabase local

**Estado:** a fazer · **Depende de:** T02, T03, T05, T06

## Objetivo

Provar no emulador, contra o Supabase local, o que as asserções SQL e os testes de widget não alcançam: o caminho real do Supabase Auth até o gatilho, os códigos de erro reais e a queda das outras sessões.

## Preparação

- `supabase start` e `supabase status` para pegar a chave pública.
- Emulador Android rodando; o app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321`.
- Mailpit aberto em `http://127.0.0.1:54324` para ler os códigos.
- Conferências no banco: `docker exec -it supabase_db_VoleiIn psql -U postgres`.

## Roteiro

| # | Cenário | Esperado |
| --- | --- | --- |
| 1 | Carla, e-mail sem conta | Pede o nome; chega `confirmacao.html` com o código; ao confirmar, cai no início com "Olá, Carla"; `pessoa` tem a linha com o id de `auth.users` |
| 2 | Carla sai e entra de novo | Vai direto ao código, sem pedir nome; chega `codigo_acesso.html` |
| 3 | Código errado | Mensagem de código inválido; continua na etapa |
| 4 | Código depois de 5 min | Recusado (`otp_expired`) |
| 5 | Mesmo código usado duas vezes | A segunda vez é recusada |
| 6 | Reenvio antes de 60 s (forçado via curl) | Servidor recusa (`over_email_send_rate_limit`) |
| 7 | Carla troca para `carla2@…` | Código só no endereço novo; aviso no antigo; o app continua logado com o e-mail novo |
| 8 | Carla com segunda sessão aberta (outro emulador ou login por curl) ao trocar o e-mail | A segunda sessão perde a renovação do token e volta para entrar |
| 9 | Carla com linhas em `dispositivo_push` (inserir à mão) ao trocar o e-mail | As linhas somem só depois da confirmação, não no pedido |
| 10 | Troca para o e-mail do Bruno, que já tem conta | Recusada com a mensagem de e-mail de outra conta (`email_exists`) |
| 11 | Pedir o código de conta nova e nunca confirmar | Anotar se já existem `auth.users` e `pessoa` para esse e-mail; ver abaixo |

## Anotar para a T10

- O código real que o Auth devolve em cada erro (ajustar `_traduzir` na T05 se diferir).
- Cenário 11: se o cadastro não confirmado já cria `pessoa`, registrar em "Aberto" no `progresso.md` (perfil órfão de e-mail digitado errado). É decisão de produto; não corrigir sem perguntar.

## Pronto quando

Os onze cenários rodaram e o resultado de cada um está anotado, com as divergências corrigidas ou registradas.

## Commit

Sem commit próprio, a não ser que um cenário exija correção; nesse caso, um commit por correção.
