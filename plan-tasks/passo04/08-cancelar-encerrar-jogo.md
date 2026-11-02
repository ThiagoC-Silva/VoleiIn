# T08 — `rpc_jogo`: cancelar e encerrar jogo

**Estado:** a fazer · **Depende de:** T06

## Objetivo

Cancelar o jogo (RF11, RN23) e encerrá-lo à mão (RF33, RN17), com o encerramento numa função interna única, que a rotina de minuto do passo 8 também chama. O encerramento libera o pagamento (RN07).

## O que já existe

- `privado.encerramento_previsto`; confirmação e cancelamento de presença.
- Textos aprovados de `jogo_cancelado` e `pagamento_liberado`, com destinatários (T01).

## O que falta

- [ ] Em `rpc_jogo`:
  - `cancelar_jogo(jogo)`: criador e admins (RN13); trava a linha; só `aberto` e antes do início (`jogo_ja_comecou`); status `cancelado`; toda cobrança ativa vira `cancelada`, inclusive multas (RN23); `jogo_cancelado` aos destinatários aprovados; já cancelado, nada muda;
  - `privado.encerrar(jogo)`: status `encerrado`; `pagamento_liberado` a cada devedor com cobrança `pendente`, com valor, credor e vencimento (`encerramento_previsto + 24 h`); quem está em `lista_espera` fica como está (RN17); já encerrado, nada muda;
  - `encerrar_jogo(jogo)`: criador e admins do grupo, no avulso só o criador (RN13, RN17); `now() >= inicio + duracao_minutos` (`jogo_nao_terminou`); chama `privado.encerrar`;
  - `grant execute` de `cancelar_jogo` e `encerrar_jogo` a `authenticated`; nenhum para `privado.encerrar`.
- [ ] `supabase/testes/rpc_jogo.sql`:
  - cancelar: membro comum recusado; criador cancela, cobranças e multas viram `canceladas`, avisos nascem; depois do início, recusado; cancelar de novo não duplica aviso; confirmar em jogo cancelado é recusado;
  - encerrar: antes do fim reservado recusado; a partir dele, criador e admin encerram; membro comum recusado; no avulso, só o criador;
  - `pagamento_liberado` só para quem tem cobrança `pendente`: não para o recebedor, nem para isentos, nem para a lista de espera;
  - a lista de espera fica `lista_espera`; editar custo depois do encerramento é recusado (completa a T07);
  - `authenticated` não executa `privado.encerrar`.

## Pronto quando

`supabase db reset` e as seis suítes imprimem `SUCESSO`.

## Commit

`Cancela e encerra jogo, liberando o pagamento`
