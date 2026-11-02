# T05 — `rpc_presenca`: confirmar presença

**Estado:** feito · **Depende de:** T04

## Objetivo

Confirmar presença (RF14, RF16, RF17, RF19) com a disputa de vaga resolvida no banco (RNF09), a fila (RN08), a isenção do cancelante tardio (RN05), a reconfirmação (RN25) e o nascimento da cobrança (RN07). A lógica fica numa função interna que a `aplicar_convite` do passo 9 reaproveita (RN22).

## O que já existe

- `privado.pode_ver_jogo` — exatamente a regra de quem confirma: membro do grupo, criador, recebedor ou quem já tem participação (RN13, decidido em 2026-11-01).
- `privado.nascer_cobranca`, `privado.avisar` (T03, T04).
- `participacao_posicao_so_na_espera`, `participacao_jogo_pessoa_unico`, `cobranca_participacao_unico`.

## O que falta

- [x] `supabase migration new rpc_presenca`, com `privado.confirmar(jogo, pessoa)` → `participacao_status`:
  - `select ... for update` na linha do jogo;
  - jogo `aberto` (`jogo_fechado`) e `now() < inicio` (`jogo_ja_comecou`, RN06);
  - já `confirmado`: devolve o status, nada muda (RNF10);
  - conta os confirmados; com vaga, a pessoa vira `confirmado` (`confirmado_em = now()`, `posicao_espera` vazia), venha da lista de espera ou não (RN08); quem estava na lista sai dela e as posições seguintes são renumeradas;
  - sem vaga: `lista_espera` na última posição; quem já está na lista continua onde está;
  - cobrança: `privado.nascer_cobranca` cria ou reabre (`pendente`, `parte`, valor atual), exceto para o recebedor (RN07, RN25);
  - RN05: se a pessoa ocupou vaga e não é ela mesma uma cancelante tardia reconfirmando, a multa `pendente` de `cancelamento_tardio` mais antiga do jogo (pelo `cancelado_em`) vira `isenta`, sem `confirmado_por`, e o isento recebe `cobranca_isenta`. Uma isenção por confirmação.
- [x] `confirmar_presenca(jogo)` → `participacao_status`: exige `privado.pode_ver_jogo` (`sem_permissao`) e chama `privado.confirmar` com `auth.uid()`; `grant execute` a `authenticated`.
- [x] `supabase/testes/rpc_presenca.sql`:
  - membro confirma e ganha cobrança `pendente` de `parte` com o `preco_por_vaga`; não membro de jogo do grupo é recusado; avulso só por quem já tem vínculo;
  - recebedor confirma sem cobrança; a soma confere: R$ 100 em 10 vagas com o recebedor jogando dá 9 cobranças de R$ 10;
  - jogo cheio: o próximo entra em `lista_espera` com a posição seguinte; confirmar de novo não muda a posição;
  - vaga livre com fila: quem é de fora confirma primeiro e fica com a vaga (RN08);
  - depois do início, recusado; jogo cancelado, recusado;
  - toque repetido não cria segunda participação nem segunda cobrança;
  - RN05 (com cancelamentos montados como `postgres` até a T06 existir, e trocados pela função depois): Ana e Bruno cancelam tarde; a primeira confirmação isenta a Ana, a segunda, o Bruno; a reconfirmação da própria Ana não isenta o Bruno e converte a multa dela em `parte`;
  - RN25: cobrança `isenta` reaberta como `pendente` de `parte`;
  - aviso pendente da T03: com confirmados, `editar_grupo` mudando o prazo avisa os de jogos sem prazo próprio e não os de jogo com prazo próprio.

## Resultado

- Migração `20261102231636_rpc_presenca.sql`, com `privado.confirmar` e `confirmar_presenca`. A `rpc_jogo` ganhou, editada no lugar, `privado.reais` (`R$ 1.234,56`) e `privado.nome_jogo` (o grupo, ou o local no avulso), que o aviso de isenção usa e a edição de jogo vai usar.
- Códigos de recusa criados: `jogo_fechado` (jogo cancelado ou encerrado) e `jogo_ja_comecou`. Reaproveitado: `sem_permissao` (42501), também para jogo que não existe.
- **Quem é cancelante tardio voltando** (RN05) se decide pela cobrança, não pelo status da participação: tem cobrança de origem `cancelamento_tardio`, `pendente` ou `isenta`. Pelo status, o cancelante que passou pela lista de espera chegaria à vaga como `lista_espera` e isentaria a multa de outro. A suíte cobre esse caminho.
- `cancelado_em` não é apagado na reconfirmação nem na entrada na lista: guarda o último cancelamento, e é por ele que se ordena a isenção da multa de quem cancelou tarde e foi para a lista sem voltar.
- O aviso `cobranca_isenta` leva à cobrança: `cobranca_id` preenchido e `jogo_id` vazio, como a coluna "Leva a" da tabela de avisos.
- Os testes de jogo, recusa e repetição seguem a ordem da task: depois do início, até quem já está confirmado recebe `jogo_ja_comecou`. É o caso do pedido atrasado (PRD, Decisões: Idempotência), que é um pedido novo.
- `rpc_presenca.sql` com 67 asserções, inclusive o aviso de prazo pendente da T03 (avisa os confirmados dos jogos que seguem o grupo; não avisa lista de espera, cancelados, nem jogo de prazo próprio, remarcado, começado ou cancelado). `schema` 70, `rls` 69, `autenticacao` 39, `rpc_grupo` 63, `rpc_jogo` 74.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Confirma presença com fila, isenção e reconfirmação`
