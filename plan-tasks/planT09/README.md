# Plano da T09 — Validação ponta a ponta no remoto

Quebra de [T09](../passo-3/09-e2e-remoto.md) em tasks executadas **uma por vez**: a seguinte só começa quando a anterior está feita, com o estado trocado nesta tabela e no cabeçalho do arquivo dela. Cada task fecha com um commit próprio. Quando a task não muda código, o commit leva só o registro dela: o "Resultado", o estado e o que mais tiver mudado nos documentos do plano.

Os itens marcados **[Thiago]** exigem conta, painel, caixa de e-mail ou o dedo no celular e são feitos à mão. Comando que pede senha ou código no terminal o Thiago roda no terminal dele, fora do Claude: o `read` do script lê `/dev/tty`, que não existe no Bash do Claude nem no modo `!` (T08.7).

## Estado conferido em 2026-10-27

- T01 a T08 e T11 a T13 feitas. A T13 só mudou o app e o script, sem migração: o remoto já tem as cinco migrações (T08.4) e não precisa de preparo no banco.
- **Remoto:** ref `zmokpmovphikmobynssy`, `https://zmokpmovphikmobynssy.supabase.co`. Chave pública por `supabase projects api-keys --project-ref zmokpmovphikmobynssy`, a de tipo `publishable`.
- **Google:** o `GOOGLE_WEB_CLIENT_ID` do remoto é o mesmo do local (`client_id` de `[auth.external.google]` no `config.toml`), e `skip_nonce_check = true` nos dois (T08.6).
- **E-mail:** Resend, remetente `nao-responda@mail.voleiin.com.br`, DMARC em `p=reject`. Teto de 30 por hora no Auth e de 100 por dia no Resend. Três envios gastos em 2026-10-27, às 14:58, 15:11 e 16:01.
- **Contas no remoto:** só o Gmail secundário do Thiago com `+t087`, confirmada e com `pessoa` (T08.7). Os dois Gmails sem sufixo seguem sem conta.
- **Script:** `supabase/testes/autenticacao_api.sh` monta os endereços como `<nome>.<época>@EMAIL_BASE`. No remoto isso mandaria código a caixas de estranhos. Sem `MAILPIT_URL`, pede cada código no terminal e pula as conferências de aviso, de "nenhum e-mail" e dos modelos; sem `PSQL`, pula as de banco.
- **Celular:** Motorola Edge 60 Pro, depuração sem fio pareada com esta máquina (T13). Instalado está o APK de depuração apontando para o Supabase local.
- **App:** o reenvio do cadastro pendente pela A1 engole `over_email_send_rate_limit` (`auth_repositorio.dart`, na entrada com senha), porque nos 60 s o código anterior ainda vale (T07, cenário 6). Se o teto por hora chegar com o mesmo código, a pessoa espera um código que não vem. A T09.8 confere.

## Decidido em 2026-10-27

Confirmadas pelo Thiago na T09.1: `PSQL` vazio, teto baixado no painel, o Thiago no celular, a senha descartável e a limpeza no fim. As outras três (endereços com `+`, MCP só de leitura e `--com-expiracao`) seguem sem objeção dele.

- **Endereços da rodada do script: `+` numa caixa real do Thiago** (T09.2). Um parâmetro novo, `EMAIL_CAIXA`, faz os endereços virarem `<usuario>+<nome>.<época>@<domínio>`. Sem isso, a única forma de rodar no remoto é mandar a domínios que não são nossos, e cada devolução pesa na reputação do `voleiin.com.br`, que é nova.
- **`PSQL` vazio no remoto.** O script não grava no banco remoto: o 12 (sessão envelhecida) e as linhas inventadas de `dispositivo_push` do 9 e do 15 ficam puladas. O que eles provam é o gatilho e a configuração `secure_password_change`, já conferidos no local (T07) e que vieram ao remoto pela mesma migração e pelo mesmo `config.toml`. A alternativa é apontar o `PSQL` para o banco remoto com a senha dele, o que deixa linhas inventadas lá.
- **Conferências de banco pelo MCP do Supabase, só de leitura**, como na T08.7. Escrita no remoto, quando houver, é do Thiago, no editor SQL do painel.
- **`--com-expiracao` na rodada.** É a única prova de que o código vence em 300 s no remoto, que veio do `config push`. Custa cinco minutos e um e-mail.
- **O teto por hora se testa baixando-o no painel** (T09.8). Para 3, por alguns minutos, e de volta a 30. A alternativa, atingir os 30 de verdade, gasta cerca de 30 e-mails reais em minutos, quase um terço do dia do Resend, numa caixa só, com um domínio sem histórico.
- **O Thiago opera o celular com o dedo.** É o uso real, os códigos chegam na caixa dele, e as telas do Google pedem a pessoa. O Claude instala, confere o servidor e registra.
  - **Mudado na T09.4, a pedido do Thiago:** o Claude opera o celular pelo `adb`, como na T07 e na T09.3, e lê os códigos nas notificações do Gmail do aparelho. Ficam com o Thiago só o que exige a pessoa: telas de consentimento ou verificação do Google, e olhar a caixa de entrada quando um e-mail não notifica.
- **Senha descartável nas contas de teste**, dita na conversa e fora de arquivo versionado, para o Claude abrir sessões por `curl` (segunda sessão do cenário 9).
- **No fim, todas as contas de teste saem do remoto** (T09.9), inclusive a `+t087`, para o remoto chegar ao passo 4 sem usuário. `pessoa` não some com `auth.users` (sem chave estrangeira, de propósito), então a ordem do SQL da T07 vale.

## Contas

Os endereços são pedidos na hora e não entram em arquivo versionado.

| Conta | Onde | Cenários |
| --- | --- | --- |
| **Gmail 1** (principal do Thiago) | celular, cadastro com senha | 1, 2, 3, 5, 9; depois 18 pelo Google |
| **Gmail 2** (secundário, sem sufixo) | celular, só Google | 17; depois é o alvo do 16 |
| **Outro provedor** (não Gmail) | celular, cadastro com senha | 6 refeito (T13), 13, 16 |
| **Gmail 2 com `+`** | script e destino da troca do 13 | a rodada inteira; `+t09` no 13 |

Na T09.4, a conta com senha foi criada no Gmail secundário, e não no principal. Desde a T09.5, os nomes valem pelo papel da tabela, não pela caixa: o Gmail 1 é o secundário, base do `+t087`, e o Gmail 2 é o principal.

Os dois Gmails precisam estar no aparelho e na lista de usuários de teste da tela de consentimento (T11).

## Orçamento de e-mail

| Task | E-mails | Quais |
| --- | --- | --- |
| T09.4 | 3 | cadastro, redefinição, aviso de senha trocada |
| T09.5 | 0 | — |
| T09.6 | 5 (gastos 7) | código do impostor, código da A2, aviso de senha trocada, código da troca, aviso de e-mail trocado; mais 2 *bounced* num endereço digitado errado |
| T09.7 | 19 | a rodada inteira, com `--com-expiracao` |
| T09.8 | até 4 | o que couber no teto baixado |

Cerca de 31 no dia, mais os 3 de hoje, contra 100 do Resend. Pelo teto de 30 por hora, a **T09.7 só começa uma hora depois do último e-mail da T09.6**: o plano não presume se o serviço conta por janela fixa ou por recarga contínua, e anota o que observar.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T09.1](01-preparacao.md) | Contas, aparelho e estado do remoto | feito | — |
| [T09.2](02-script-caixa-real.md) | Endereços com `+` no script | feito | — |
| [T09.3](03-apk-release.md) | APK release apontando para o remoto | feito | T09.1 |
| [T09.4](04-celular-senha.md) | Celular: cadastro, entrada e redefinição | feito | T09.3 |
| [T09.5](05-celular-google.md) | Celular: Google | feito | T09.4 |
| [T09.6](06-celular-outro-provedor.md) | Celular: cadastro refeito e troca de e-mail | feito | T09.5 |
| [T09.7](07-rodada-script.md) | Rodada do script no remoto | feito | T09.2, T09.6 |
| [T09.8](08-teto-de-emails.md) | Teto de e-mails por hora | feito | T09.7 |
| [T09.9](09-registro-e-limpeza.md) | Resend, limpeza e fechamento da T09 | a fazer | T09.8 |

A T09.2 não envia e-mail nem mexe no celular: pode ser feita antes da T09.3 ou entre as outras, desde que antes da T09.7.

## Para a execução

- **Parar** se um código chegar no spam ou não chegar: olhar primeiro os registros do Resend (com `p=reject`, falha de autenticação é recusa, não spam) e voltar à configuração de domínio da T08 antes de seguir.
- **Parar** se o Google recusar o token no remoto: a decisão do `skip_nonce_check` volta (T08.6).
- **Parar** se o comportamento do remoto divergir do local num cenário que já passou na T07. Anotar o `error_code`, e decidir com o Thiago antes de mudar o app.
- Nenhuma mudança no `config.toml` nem no painel além da do teto da T09.8, que volta a 30 na mesma task.

## Modelo de task

```
# T09.N — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** T09.x
## Objetivo
## O que já existe
## O que falta
## Resultado        ← preenchido na execução
## Pronto quando
## Commit
```
