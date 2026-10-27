# T09.2 — Endereços com `+` no script

**Estado:** a fazer · **Depende de:** —

## Objetivo

Deixar o `supabase/testes/autenticacao_api.sh` rodar no remoto mandando todos os e-mails a uma caixa real do Thiago, e não a `<nome>.<época>@<domínio>` de estranhos.

## O que já existe

- `email_unico <nome>` devolve `$1.$EPOCA@$EMAIL_BASE`. Todo endereço da rodada passa por ela; o `--impostor` recebe o endereço pronto e não passa.
- O Auth aceita `+` no endereço (o `+t087` da T08.7), e o Gmail entrega `usuario+qualquer@gmail.com` na caixa de `usuario@gmail.com`.
- Sem `MAILPIT_URL`, `codigo_de` pede o código por `/dev/tty`, com o endereço e o assunto no texto da pergunta.
- No `cenario_refeito`, o código do impostor é lido e descartado: sem Mailpit, a pergunta aparece do mesmo jeito.

## O que falta

- [ ] Parâmetro `EMAIL_CAIXA`, vazio por padrão, documentado no topo junto dos outros. Com ele preenchido (`usuario@dominio`), `email_unico` devolve `usuario+<nome>.<época>@dominio`; vazio, segue o `EMAIL_BASE` como hoje.
- [ ] Na pergunta do código descartado do `cenario_refeito`, dizer que basta apertar Enter. Sem isso, o Thiago vai procurar um código que não importa enquanto os 60 s correm.
- [ ] Linha do `supabase/CLAUDE.md` com a forma de rodar no remoto: `AUTH_URL`, `CHAVE`, `MAILPIT_URL=`, `PSQL=` e `EMAIL_CAIXA`.
- [ ] Rodada local com Mailpit e `EMAIL_CAIXA=fulano@exemplo.com`: os endereços saem com `+`, o Mailpit os acha pela busca `to:"…"`, e a rodada passa. Depois, a rodada sem `EMAIL_CAIXA` passa como antes. Entre uma e outra, cinco minutos, pelo limite por IP (T07).

## Resultado

## Pronto quando

As duas rodadas locais passam, com 18 cenários cada, e a linha de comando do remoto está no `supabase/CLAUDE.md`.

## Commit

`Permite endereços com + numa caixa real no roteiro de autenticação`
