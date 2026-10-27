# T09.2 — Endereços com `+` no script

**Estado:** feito · **Depende de:** —

## Objetivo

Deixar o `supabase/testes/autenticacao_api.sh` rodar no remoto mandando todos os e-mails a uma caixa real do Thiago, e não a `<nome>.<época>@<domínio>` de estranhos.

## O que já existe

- `email_unico <nome>` devolve `$1.$EPOCA@$EMAIL_BASE`. Todo endereço da rodada passa por ela; o `--impostor` recebe o endereço pronto e não passa.
- O Auth aceita `+` no endereço (o `+t087` da T08.7), e o Gmail entrega `usuario+qualquer@gmail.com` na caixa de `usuario@gmail.com`.
- Sem `MAILPIT_URL`, `codigo_de` pede o código por `/dev/tty`, com o endereço e o assunto no texto da pergunta.
- No `cenario_refeito`, o código do impostor é lido e descartado: sem Mailpit, a pergunta aparece do mesmo jeito.

## O que falta

- [x] Parâmetro `EMAIL_CAIXA`, vazio por padrão, documentado no topo junto dos outros. Com ele preenchido (`usuario@dominio`), `email_unico` devolve `usuario+<nome>.<época>@dominio`; vazio, segue o `EMAIL_BASE` como hoje.
- [x] O código descartado do `cenario_refeito` não pode fazer o Thiago procurar um código que não importa enquanto os 60 s correm. Resolvido sem pergunta nenhuma (item abaixo), em vez do "aperte Enter" planejado.
- [x] Linha do `supabase/CLAUDE.md` com a forma de rodar no remoto: `AUTH_URL`, `CHAVE`, `MAILPIT_URL=`, `PSQL=` e `EMAIL_CAIXA`.
- [x] Sem Mailpit, os outros dois pontos que quebravam, achados na execução:
  - o código descartado do 6 (o primeiro da Eva) e o do refeito (o do impostor) eram perguntados no terminal. Agora `descarta_codigo` só os marca como lidos com Mailpit, e sem ele não pergunta;
  - o `cadastro_de_novo` do 6 lia o Mailpit direto. Sem ele, anotaria "nenhum código novo" sempre e confirmaria com código velho. Agora `codigo_novo_de` pergunta se chegou outro, e Enter vale como "não".
- [x] Rodada local com Mailpit e `EMAIL_CAIXA=fulano@exemplo.com`: os endereços saem com `+`, o Mailpit os acha pela busca `to:"…"`, e a rodada passa. Depois, a rodada sem `EMAIL_CAIXA` passa como antes. Entre uma e outra, cinco minutos, pelo limite por IP (T07).

## Resultado

Feito em 2026-10-27.

- **Script:** `EMAIL_CAIXA` no topo e em `email_unico`; `descarta_codigo` e `codigo_novo_de` novos; a pergunta do código diz "mais recente", porque a caixa real guarda os anteriores.
- **Rodada com `EMAIL_CAIXA=fulano@exemplo.com`:** `SUCESSO: 18 cenários`, 2 min 46 s, modelos 5 de 5. Os 18 e-mails foram a `fulano+<nome>.<época>@exemplo.com`, nenhum sem `+`.
- **Rodada sem `EMAIL_CAIXA`:** `SUCESSO: 18 cenários`, 18 e-mails, como antes.
- **A rodada gasta 18 e-mails, não 19:** contados no Mailpit pelas duas rodadas (Bruno 3, Carla 4, Carla2 1, Eva 2, Eva2 2, Fábio 1, Gil 2, Helena 3). O 19 da T13 estava errado; com `--com-expiracao`, são 19. Corrigido no README, na T09.7 e na [T09](../passo-3/09-e2e-remoto.md).
- **Sem Mailpit, num terminal falso:** um driver em Python, fora do repositório, abriu o script num pty com `MAILPIT_URL=`, `PSQL=` e `EMAIL_CAIXA`, e respondeu cada pergunta com o código mais novo do Mailpit, como uma pessoa olhando a caixa. `SUCESSO: 18 cenários`, 21 conferências puladas. Foram 13 perguntas: 12 códigos e um Enter (o segundo cadastro da Eva2 antes de 60 s, que não envia). Os descartados não perguntaram. Com `--com-expiracao`, a T09.7 terá 14.

## Pronto quando

As duas rodadas locais passam, com 18 cenários cada, e a linha de comando do remoto está no `supabase/CLAUDE.md`.

## Commit

`Permite endereços com + numa caixa real no roteiro de autenticação`
