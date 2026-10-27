# T09.7 — Rodada do script no remoto

**Estado:** a fazer · **Depende de:** T09.2, T09.6

## Objetivo

A rodada inteira do `autenticacao_api.sh` contra o remoto, com os códigos digitados no terminal. Mostra os códigos de erro do remoto cenário a cenário, o vencimento de 300 s e o caminho sem Mailpit, que nunca rodou.

## O que já existe

- O `EMAIL_CAIXA` da T09.2.
- A rodada local: 18 cenários, 19 e-mails, 2 min 46 s; com `--com-expiracao`, mais um e-mail e mais cinco minutos.
- Sem `MAILPIT_URL` ficam pulados: os avisos, o "nenhum e-mail" e os modelos. Sem `PSQL`: o 12 e as conferências de banco, inclusive as linhas de `dispositivo_push` do 9 e do 15. O fim da rodada diz quantas foram puladas.
- Cada código vale cinco minutos e tem de ser digitado antes disso.

## O que falta

- [ ] Uma hora depois do último e-mail da T09.6.
- [ ] **[Thiago]** No terminal dele, a partir da raiz:

  ```
  AUTH_URL=https://zmokpmovphikmobynssy.supabase.co/auth/v1 \
  CHAVE=<chave pública> MAILPIT_URL= PSQL= EMAIL_CAIXA=<Gmail 2> \
    supabase/testes/autenticacao_api.sh --com-expiracao 2>&1 | tee <scratchpad>/rodada-remoto.txt
  ```

  O `tee` não atrapalha a pergunta do código, que vai por `/dev/tty`. Cada pergunta traz o endereço com `+` e o assunto, para achar o e-mail certo na caixa.
- [ ] **[Thiago]** Na caixa, depois da rodada, conferir o que o script pulou:
  - chegaram os avisos de senha trocada do 9, do refeito e do 12, e o de e-mail trocado do 13;
  - no 13, o endereço antigo (`+carla.…`) não recebeu o código da troca, só o aviso;
  - nada chegou ao `+ninguem.…` do 10, que não tem conta;
  - o total de mensagens da rodada na caixa é 20.
- [ ] Ler a saída e preencher a tabela do Resultado com o status e o `error_code` de cada cenário, contra a coluna da T07. Em especial: e-mail inválido (`validation_failed` ou `email_address_invalid`), o 5, e o código vencido do 7.
- [ ] Se a rodada parar num `FALHOU`, **parar**: é divergência entre remoto e local, e se decide com o Thiago antes de mexer em script ou app.

## Resultado

## Pronto quando

`SUCESSO: 18 cenários` contra o remoto, com o número de conferências puladas anotado, e os códigos de erro do remoto numa tabela ao lado dos do local.

## Commit

`Registra a rodada do roteiro de autenticação no remoto`
