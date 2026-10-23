# Plano da T07 — Validação ponta a ponta no Supabase local

Quebra de [T07](../passo-3/07-e2e-local.md) em tasks executadas **uma por vez**: a seguinte só começa quando a anterior está feita, com o estado trocado nesta tabela e no cabeçalho do arquivo dela. Cada task fecha com um commit próprio. Quando a task não muda código, o commit leva só o registro dela: o "Resultado", o estado e o que mais tiver mudado nos documentos do plano. Assim nenhuma anotação fica esperando a T07.11.

O roteiro dos 22 cenários continua em [`07-e2e-local.md`](../passo-3/07-e2e-local.md); aqui fica só a ordem de execução e o que cada rodada entrega.

## Estado conferido em 2026-10-23

- T01 a T06, T11 e T12 feitas; T07 é a única task do passo 3 com todas as dependências fechadas, e T08, T09 e T10 esperam por ela.
- Suítes SQL: schema 61, rls 69, autenticacao 36 asserções, todas passam. `dart analyze` sem erro; `flutter test` com 24 testes.
- Supabase local no ar, Auth (GoTrue) v2.197.0, Mailpit em `http://127.0.0.1:54324`, `supabase/.env` com o segredo do Google.
- `supabase/testes/autenticacao_api.sh` ainda não existe.
- Celular físico (Motorola Edge 60 Pro) visível pelo `adb` por depuração sem fio. Emulador `voleiin` (Android 35, imagem `google_apis_playstore`) disponível como reserva. `apksigner` instalado em `~/Android/Sdk/build-tools/`.

## Decisões de 2026-10-23

- **Gmail reaproveitado.** Há dois Gmails na lista de usuários de teste do Google (T11). O de teste fica com a Diana (cenários 17, 20, 21); o do Thiago serve ao impostor (19) e, depois de apagada a conta por `psql`, ao Bruno (18).
- **Cenário 22 por chave descartável.** O APK de debug é reassinado com uma keystore criada no scratchpad, sem tocar em `build.gradle.kts` nem em `~/.android/debug.keystore`. O que se quer saber: se a chave sem cadastro no Google chega como `canceled`, o app volta sem mensagem e a pessoa fica sem pista.
- ~~**Limite de 30 e-mails por hora no local.**~~ Não vale no local: sem SMTP próprio, o CLI ignora `email_sent` (conferido na T07.6). O `config.toml` continua sem mudar, porque tem de seguir igual ao remoto.
- **O celular é operado pelo Claude**, pelo `adb`: toques com `input tap`, elementos por `uiautomator dump`, conferência por `screencap`. Ficam com o Thiago:
  - a conferência do teclado das seis casas e do colar, com o dedo, antes de qualquer tecla injetada pelo `adb`;
  - adicionar ao aparelho as contas Google que faltarem;
  - telas de consentimento ou verificação do Google, se aparecerem.

## Para a execução

- Até a sessão ser reaberta com o grupo `docker`, os comandos do Docker rodam com `sg docker -c '…'` (`docs/progresso.md`, passo 1).
- **Parar e reabrir a decisão** se, no cenário 19, a senha do impostor sobreviver à vinculação do Google: contraria a RN21 e a premissa do cadastro confirmado por código.
- **Parar e corrigir** a T02 ou a T03 se um cadastro não confirmado criar `pessoa`: é defeito, não decisão aberta.
- Os endereços dos dois Gmails não entram em arquivo versionado; são pedidos na hora.

## Tasks

| # | Task | Estado | Depende de |
| --- | --- | --- | --- |
| [T07.1](01-roteiro-atualizado.md) | Atualizar o roteiro da T07 com as decisões | feito | — |
| [T07.2](02-script-base.md) | Base do script e cenários 1 a 5 | feito | T07.1 |
| [T07.3](03-script-confirmacao.md) | Script: confirmação, códigos e reenvio (6 a 8) | feito | T07.2 |
| [T07.4](04-script-senha.md) | Script: redefinição e troca de senha (9 a 12) | feito | T07.3 |
| [T07.5](05-script-troca-email.md) | Script: troca de e-mail, modelos e impostor (13 a 16) | feito | T07.4 |
| [T07.6](06-rodada-completa.md) | Rodada completa e correção das mensagens | feito | T07.5 |
| [T07.7](07-preparar-celular.md) | Preparar o celular e conferir o teclado | feito | T07.6 |
| [T07.8](08-celular-senha.md) | Celular: cenários de e-mail e senha | feito | T07.7 |
| [T07.9](09-celular-google.md) | Celular: cenários do Google (17 a 21) | a fazer | T07.8 |
| [T07.10](10-chave-sem-cadastro.md) | Celular: build com chave sem cadastro (22) | a fazer | T07.9 |
| [T07.11](11-registro.md) | Registro dos resultados e fechamento da T07 | a fazer | T07.10 |

## Modelo de task

```
# T07.N — Nome
**Estado:** feito | parcial | a fazer · **Depende de:** T07.x
## Objetivo
## O que já existe
## O que falta
## Resultado        ← preenchido na execução
## Pronto quando
## Commit
```
