# T09.7 — Rodada do script no remoto

**Estado:** feito · **Depende de:** T09.2, T09.6

## Objetivo

A rodada inteira do `autenticacao_api.sh` contra o remoto, com os códigos digitados no terminal. Mostra os códigos de erro do remoto cenário a cenário, o vencimento de 300 s e o caminho sem Mailpit, que nunca rodou.

## O que já existe

- O `EMAIL_CAIXA` da T09.2.
- A rodada local: 18 cenários, 18 e-mails, 2 min 46 s (contados na T09.2; a T13 anotou 19); com `--com-expiracao`, mais um e-mail e mais cinco minutos.
- Sem `MAILPIT_URL` ficam pulados: os avisos, o "nenhum e-mail" e os modelos. Sem `PSQL`: o 12 e as conferências de banco, inclusive as linhas de `dispositivo_push` do 9 e do 15. O fim da rodada diz quantas foram puladas.
- Cada código vale cinco minutos e tem de ser digitado antes disso. São 14 perguntas: 13 códigos e uma de "chegou outro?", que pede Enter quando não chegou (T09.2).

## O que falta

- [x] Uma hora depois do último e-mail da T09.6.
- [x] **[Thiago]** No terminal dele, a partir da raiz:

  ```
  AUTH_URL=https://zmokpmovphikmobynssy.supabase.co/auth/v1 \
  CHAVE=<chave pública> MAILPIT_URL= PSQL= EMAIL_CAIXA=<Gmail 2> \
    supabase/testes/autenticacao_api.sh --com-expiracao 2>&1 | tee <scratchpad>/rodada-remoto.txt
  ```

  O `tee` não atrapalha a pergunta do código, que vai por `/dev/tty`. Cada pergunta traz o endereço com `+` e o assunto, para achar o e-mail certo na caixa.
- [x] **[Thiago]** Na caixa, depois da rodada, conferir o que o script pulou:
  - chegaram os avisos de senha trocada do 9, do refeito e do 12, e o de e-mail trocado do 13;
  - no 13, o endereço antigo (`+carla.…`) não recebeu o código da troca, só o aviso;
  - nada chegou ao `+ninguem.…` do 10, que não tem conta;
  - o total de mensagens da rodada na caixa é 19.
- [x] Ler a saída e preencher a tabela do Resultado com o status e o `error_code` de cada cenário, contra a coluna da T07. Em especial: e-mail inválido (`validation_failed` ou `email_address_invalid`), o 5, e o código vencido do 7.
- [x] Se a rodada parar num `FALHOU`, **parar**: é divergência entre remoto e local, e se decide com o Thiago antes de mexer em script ou app.

## Resultado

Feito em 2026-10-28, das 14:07 às 14:22 UTC (11:07 às 11:22 em Brasília), 13 h 25 min depois do último e-mail da T09.6. O Thiago rodou no terminal dele, com `EMAIL_CAIXA` no Gmail 2, e mandou a saída e uma captura da caixa.

- **`SUCESSO: 18 cenários`, 21 conferências puladas**, as mesmas 21 da rodada simulada da T09.2. Nenhum `FALHOU`, e nenhum código de erro diferente do local.
- **Perguntas:** 14, como previsto. Foram 12 de código e duas de "chegou outro?" à `+eva2`, e não 13 e uma, como o "O que já existe" contou: a de antes de 60 s pede Enter, e a de depois de 60 s pede o código novo.
- **Um código digitado onde cabia Enter.** Na pergunta de antes de 60 s, o Thiago digitou `800824`, provavelmente o primeiro código da `+eva`, que o script descarta sem perguntar e que chegou na mesma hora. O cadastro dessa hora deu 429, e a caixa tem só os dois "Confirme seu cadastro" esperados da `+eva2`: o remoto não mandou código. Só a anotação "enviou código novo" daquela linha sai errada. A confirmação usou o código digitado depois de 60 s, e o 6 não foi afetado.
- **E-mails:** 19, todos na caixa de entrada do Gmail, agrupados por assunto, sem nenhum no spam: "Confirme seu cadastro" 11 (Carla, Eva ×2, Eva2 ×2, Helena ×2, Fábio, Heitor, Bruno, Gil), "Seu código para redefinir a senha" 3 (Bruno, Gil, Carla), "A senha da sua conta foi trocada" 3 (9, refeito e 12), "Confirme a troca de e-mail" 1 (só a `+carla2`) e "O e-mail da sua conta foi trocado" 1 (a `+carla`). Nenhum "redefinir" à `+ninguem`. Como o total bate com o esperado, a caixa cobre também os "nenhum e-mail" que o script pulou (2, 5, 10, 11, o endereço antigo do 13 e 16): qualquer envio a mais teria passado de 19.
- **Teto por hora:** 19 envios em 15 min, sem recusa, abaixo dos 30. No dia (UTC), 26 envios: 7 da T09.6 e 19 desta.
- **Contas que a rodada deixa no remoto**, todas com `+<nome>.1793196422547` no Gmail 2: Carla (agora no endereço da `+carla2`), Eva, Eva2, Helena, Fábio, Bruno e Gil confirmadas, e Heitor pendente. Saem na T09.9.

| Cenário | Remoto | Local (T07) | `error_code` no remoto |
| --- | --- | --- | --- |
| 1 | `/signup` 200, código confirma com 200 e sessão do mesmo id. `pessoa` não conferida (sem `PSQL`) | igual | — |
| 2 | 200 com sessão do mesmo id | igual | — |
| 3 | 400 | igual | `invalid_credentials` |
| 4 | 422 | igual | `weak_password` |
| 5 | 422 | igual | `user_already_exists` |
| e-mail inválido | `carla@`: 400. O `email_address_invalid` não apareceu no remoto também | igual | `validation_failed` |
| 6 | Entrada sem confirmar 400; reenvio logo depois 429; depois de 61 s, 200 e o código novo entra. Eva2: segundo cadastro antes de 60 s 429, depois de 60 s 200 com o mesmo id e código novo; confirmada, entra só a senha do **primeiro** pedido, e as outras duas dão 400 | igual | `email_not_confirmed`, `over_email_send_rate_limit`, `invalid_credentials` |
| refeito | Cadastro do impostor e, depois de 61 s, o da Helena: 200 com o mesmo id; o código confirma; o app grava nome (204) e senha (200); a senha do impostor é recusada, a da Helena entra, e o perfil diz "Helena" | igual | `invalid_credentials` |
| 7 | Código errado, repetido e vencido (301 s): 403 nos três. **O código vence em 300 s no remoto** | igual | `otp_expired` nos três |
| 8 | 429 no reenvio antes de 60 s | igual | `over_email_send_rate_limit` |
| 9 | A troca de senha sozinha já derruba a sessão C (400), antes do `logout?scope=others` (204); depois dele, B e C recusadas e a sessão do código renova. A senha antiga dá 400, a nova entra. Linhas de `dispositivo_push` não conferidas (sem `PSQL`) | igual | `refresh_token_not_found`, `invalid_credentials` |
| 10 | 200 com o corpo igual ao do `/recover` de e-mail com conta; nada chegou à `+ninguem` | igual | — |
| 11 | 422; a sessão do código continua de pé (`GET /user` 200, renovação 200), e não chegou aviso | igual | `same_password` |
| 12 | Só o caminho do app: código de redefinição, sessão nova e `PUT /user` 200, com aviso. A troca por sessão de 25 h ficou pulada (sem `PSQL`) | o `reauthentication_needed` não foi conferido no remoto | — |
| 13 | Pedido 200 com o e-mail antigo ainda na conta; código só na `+carla2`; o `/verify` devolve sessão nova, que fica com o e-mail novo e renova; a sessão A, substituída, dá 400; aviso na `+carla` | igual | `refresh_token_not_found` |
| 14 | A troca sozinha **não** derruba a sessão B (200); o `logout?scope=others` derruba (400) | igual | `refresh_token_not_found` |
| 15 | Pulado (sem `PSQL`): só as contagens de `dispositivo_push` | não conferido no remoto | — |
| 16 | 422 | igual | `email_exists` |

## Pronto quando

`SUCESSO: 18 cenários` contra o remoto, com o número de conferências puladas anotado, e os códigos de erro do remoto numa tabela ao lado dos do local.

## Commit

`Registra a rodada do roteiro de autenticação no remoto`
