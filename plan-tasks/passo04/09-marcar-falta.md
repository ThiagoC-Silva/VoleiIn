# T09 — `rpc_presenca`: marcar falta

**Estado:** a fazer · **Depende de:** T08

## Objetivo

Marcar quem faltou (RF18, RN04), só com o jogo encerrado e dentro da janela de 24 horas.

## O que já existe

- `privado.encerrar` e `encerrar_jogo` (T08); `privado.encerramento_previsto`.
- Texto aprovado de `falta_marcada` (T01).

## O que falta

- [ ] Em `rpc_presenca`, `marcar_falta(jogo, pessoa)`:
  - recebedor do jogo e admins do grupo; no avulso, só o recebedor (RN04, RN13);
  - jogo `encerrado` (`jogo_nao_encerrado`) e `now() <= encerramento_previsto + 24 h` (`janela_de_falta_encerrada`);
  - participação `confirmado` vira `faltou`; a cobrança de origem `parte` vira `falta` com o mesmo valor, qualquer que seja o status dela — inclusive já paga, a exceção aceita na âncora de retenção (`docs/modelo-de-dados.md`);
  - participação que não é `confirmado` é recusada (`nao_confirmado`); já `faltou`, nada muda;
  - `falta_marcada` ao faltoso;
  - `grant execute` a `authenticated`.
- [ ] `supabase/testes/rpc_presenca.sql`:
  - antes do encerramento, recusado; depois de `encerramento_previsto + 24 h`, recusado;
  - recebedor marca; admin marca; criador que não é recebedor nem admin é recusado; no avulso, só o recebedor;
  - status e origem mudam juntos; valor igual; aviso nasce; marcar de novo não duplica;
  - marcar o recebedor confirmado: vira `faltou`, sem cobrança a mudar.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Marca falta depois do encerramento`
