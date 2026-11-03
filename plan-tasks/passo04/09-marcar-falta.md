# T09 — `rpc_presenca`: marcar falta

**Estado:** feito · **Depende de:** T08

## Objetivo

Marcar quem faltou (RF18, RN04), só com o jogo encerrado e dentro da janela de 24 horas.

## O que já existe

- `privado.encerrar` e `encerrar_jogo` (T08); `privado.encerramento_previsto`.
- Texto aprovado de `falta_marcada` (T01).

## O que falta

- [x] Em `rpc_presenca`, `marcar_falta(jogo, pessoa)`:
  - recebedor do jogo e admins do grupo; no avulso, só o recebedor (RN04, RN13);
  - jogo `encerrado` (`jogo_nao_encerrado`) e `now() <= encerramento_previsto + 24 h` (`janela_de_falta_encerrada`);
  - participação `confirmado` vira `faltou`; a cobrança de origem `parte` vira `falta` com o mesmo valor, qualquer que seja o status dela — inclusive já paga ou isenta, a exceção aceita na âncora de retenção (`docs/modelo-de-dados.md`; a isenta decidida em 2026-11-02);
  - participação que não é `confirmado` é recusada (`nao_confirmado`); já `faltou`, nada muda;
  - `falta_marcada` ao faltoso; o recebedor, sem cobrança, recebe a versão sem a frase do valor, levando ao jogo (decidido em 2026-11-02);
  - `grant execute` a `authenticated`.
- [x] `supabase/testes/rpc_presenca.sql`:
  - antes do encerramento, recusado; depois de `encerramento_previsto + 24 h`, recusado;
  - recebedor marca; admin marca; criador que não é recebedor nem admin é recusado; no avulso, só o recebedor;
  - status e origem mudam juntos; valor igual; aviso nasce; marcar de novo não duplica;
  - marcar o recebedor confirmado: vira `faltou`, sem cobrança a mudar.

## Resultado

- `marcar_falta(jogo, pessoa)` em `rpc_presenca`, devolvendo vazio.
- **Ordem das checagens:** papel (`sem_permissao`), jogo encerrado (`jogo_nao_encerrado`), janela (`janela_de_falta_encerrada`) e, por fim, a participação. Como na confirmação depois do início, a hora vem antes da idempotência: repetir a marcação depois da janela é recusado, não ignorado.
- **A janela inclui o último instante:** `now() <= encerramento_previsto + 24 h`; um minuto depois, recusa.
- **Cobrança:** a de origem `parte` vira `falta` em qualquer status, inclusive paga ou isenta (decidido em 2026-11-02, RN04 e âncora da retenção no modelo). O par `confirmado_por`/`confirmado_em` fica como estava. O recebedor só muda de participação: a regra é pelo `recebedor_id`, e não pelo status da cobrança, então a cobrança cancelada que ele guarde de antes de virar recebedor não é tocada.
- **Aviso:** o nome inteiro de quem marca; a data do início sem a vírgula do dia da semana ("Areia de Sábado, seg 16 nov"), como o G1 e a tabela de avisos. O do recebedor perde a frase do valor e leva ao jogo. Quem marca a própria falta não é avisado.
- Pessoa sem participação no jogo também recusa com `nao_confirmado`.
- Os cenários de paga e isenta gravam o status como postgres, porque `dar_baixa` e `isentar_cobranca` chegam na T10; a âncora da T10 repete o caso pelas funções.
- Códigos de recusa novos: `jogo_nao_encerrado`, `janela_de_falta_encerrada`, `nao_confirmado`. Reaproveitado: `sem_permissao`.
- `rpc_presenca.sql` com 126 asserções; `schema` 70, `rls` 69, `autenticacao` 39, `rpc_grupo` 63, `rpc_jogo` 164.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Marca falta depois do encerramento`
