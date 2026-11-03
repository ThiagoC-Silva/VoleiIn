# T12 — Concorrência

**Estado:** feito · **Depende de:** T05, T07

## Objetivo

Provar com duas sessões de verdade o que uma transação única não consegue simular: a disputa pela última vaga (RNF09) e a disputa pela mesma quadra ou pela capacidade do local (RN15, fila por local).

## O que já existe

- `select ... for update` em `privado.confirmar` (T05) e `pg_advisory_xact_lock` por local em `criar_jogo`, `duplicar_jogo` e `editar_jogo` (T04, T07).
- As suítes SQL rodam numa transação só e são desfeitas; não servem aqui.

## O que falta

- [x] `supabase/testes/concorrencia.sh`, que fala com o banco local por `docker exec ... psql`:
  - prepara os dados **gravados** (pessoas, grupo, jogo com uma vaga livre), com ids próprios para a limpeza;
  - **última vaga:** duas sessões, agindo como pessoas diferentes (`set_config` de `role` e `request.jwt.claims`), chamam `confirmar_presenca` ao mesmo tempo; uma segura a transação aberta com `pg_sleep` depois de confirmar, para a outra esbarrar no `for update`; conferir um `confirmado` e um `lista_espera`;
  - **mesma quadra:** duas `criar_jogo` simultâneas na mesma quadra e horário: um jogo e uma recusa `quadra_ocupada`;
  - **capacidade:** no Ginásio, com um jogo já gravado, duas criações simultâneas no mesmo horário: uma passa e a outra recusa `local_lotado`;
  - limpa tudo o que criou, mesmo se uma conferência falhar (`trap`);
  - imprime `SUCESSO: N cenários` ou para no primeiro `FALHOU`, como `autenticacao_api.sh`.
- [x] Rodar o script três vezes seguidas, para não confiar numa vitória de sorte.

## Resultado

- `supabase/testes/concorrencia.sh`, com três pessoas e um grupo gravados com ids próprios (`cc…`). Os jogos ficam numa segunda-feira dez semanas à frente, para não esbarrar no seed nem no uso do app. A limpeza roda no começo, contra resto de rodada interrompida, e no fim pelo `trap`, mesmo depois de um `FALHOU`.
- **Como a disputa acontece:** a sessão A faz a operação e segura a transação por 3 s (`pg_sleep`); a B espera 1 s dentro do próprio banco e faz a mesma operação. O roteiro confere o resultado e também o tempo da B, que tem de passar de 2 s. Sem a espera, uma vitória de B por ordem de chegada passaria despercebida. As três rodadas mediram por volta de 3,1 s.
- **Prova de que a trava decide:** com uma cópia de `privado.nascer_jogo` sem o `pg_advisory_xact_lock`, aplicada só no banco local, o cenário da quadra falha: as duas criações passam. Depois, `supabase db reset`.
- Três rodadas seguidas com `SUCESSO: 3 cenários`; depois delas, nenhuma pessoa `cc…`, nenhum jogo, grupo ou aviso no banco, e as oito suítes SQL verdes.

## Pronto quando

```
supabase db reset
supabase/testes/concorrencia.sh   # SUCESSO: 3 cenários, três vezes
```

e as oito suítes SQL seguem verdes depois dele: a limpeza não deixou resto.

## Commit

`Confere a disputa de vaga e de quadra com duas sessões`
