# T10 — `rpc_cobranca`: baixa e isenção

**Estado:** a fazer · **Depende de:** T09

## Objetivo

Dar baixa (RF22) e isentar à mão (RF23), só pelo credor e só depois do encerramento (RN07, RN13), e provar a âncora da retenção do comprovante: depois do encerramento, nenhuma função altera cobrança inativa, salvo a falta (RN19, `docs/modelo-de-dados.md`).

## O que já existe

- `cobranca_confirmacao_em_par` (o par `confirmado_por`/`confirmado_em` anda junto).
- Todo o ciclo do jogo até a falta (T04 a T09).
- Textos aprovados de `cobranca_confirmada` e `cobranca_isenta` (T01).

## O que falta

- [ ] `supabase migration new rpc_cobranca`, com:
  - `dar_baixa(cobranca)`: só o credor (`sem_permissao`); jogo `encerrado` (`pagamento_nao_liberado`); `pendente` ou `comprovante_enviado` vira `confirmado`, com `confirmado_por = auth.uid()` e `confirmado_em = now()`; `cobranca_confirmada` ao devedor; já `confirmado`, nada muda; `isenta` ou `cancelada`, recusado (`cobranca_resolvida`);
  - `isentar_cobranca(cobranca)`: mesmas condições; vira `isenta` com o par preenchido; `cobranca_isenta` ao devedor; já `isenta`, nada muda;
  - `grant execute` das duas a `authenticated`.
- [ ] `supabase/testes/rpc_cobranca.sql`:
  - devedor e terceiro recusados; credor antes do encerramento recusado (congelamento da RN07);
  - baixa e isenção preenchem o par e avisam; repetir não duplica aviso; baixa em cobrança isenta recusada;
  - depois da troca de recebedor (T07), só o novo credor dá baixa;
  - **âncora da retenção:** encerrado o jogo, guardar o `atualizado_em` de cada cobrança inativa (`confirmado`, `isenta`, `cancelada`); rodar, em todas as cobranças e participações do jogo, cada função que o app alcança depois do encerramento — `dar_baixa`, `isentar_cobranca`, `editar_jogo`, `cancelar_jogo`, `encerrar_jogo`, `confirmar_presenca`, `cancelar_presenca`, `marcar_falta` —, aceitando as recusas; conferir que nenhum `atualizado_em` mudou, exceto o da cobrança já paga cuja falta foi marcada.

## Pronto quando

`supabase db reset` e as sete suítes imprimem `SUCESSO`.

## Commit

`Dá baixa e isenta cobrança, e confere a âncora da retenção`
