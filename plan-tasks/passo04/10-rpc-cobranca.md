# T10 — `rpc_cobranca`: baixa e isenção

**Estado:** feito · **Depende de:** T09

## Objetivo

Dar baixa (RF22) e isentar à mão (RF23), só pelo credor e só depois do encerramento (RN07, RN13), e provar a âncora da retenção do comprovante: depois do encerramento, nenhuma função altera cobrança inativa, salvo a falta (RN19, `docs/modelo-de-dados.md`).

## O que já existe

- `cobranca_confirmacao_em_par` (o par `confirmado_por`/`confirmado_em` anda junto).
- Todo o ciclo do jogo até a falta (T04 a T09).
- Textos aprovados de `cobranca_confirmada` e `cobranca_isenta` (T01).

## O que falta

- [x] `supabase migration new rpc_cobranca`, com:
  - `dar_baixa(cobranca)`: só o credor (`sem_permissao`); jogo `encerrado` (`pagamento_nao_liberado`); `pendente` ou `comprovante_enviado` vira `confirmado`, com `confirmado_por = auth.uid()` e `confirmado_em = now()`; `cobranca_confirmada` ao devedor; já `confirmado`, nada muda; `isenta` ou `cancelada`, recusado (`cobranca_resolvida`);
  - `isentar_cobranca(cobranca)`: mesmas condições; vira `isenta` com o par preenchido; `cobranca_isenta` ao devedor; já `isenta`, nada muda;
  - `grant execute` das duas a `authenticated`.
- [x] `supabase/testes/rpc_cobranca.sql`:
  - devedor e terceiro recusados; credor antes do encerramento recusado (congelamento da RN07);
  - baixa e isenção preenchem o par e avisam; repetir não duplica aviso; baixa em cobrança isenta recusada;
  - depois da troca de recebedor (T07), só o novo credor dá baixa;
  - **âncora da retenção:** encerrado o jogo, guardar o `atualizado_em` de cada cobrança inativa (`confirmado`, `isenta`, `cancelada`); rodar, em todas as cobranças e participações do jogo, cada função que o app alcança depois do encerramento — `dar_baixa`, `isentar_cobranca`, `editar_jogo`, `cancelar_jogo`, `encerrar_jogo`, `confirmar_presenca`, `cancelar_presenca`, `marcar_falta` —, aceitando as recusas; conferir que nenhum `atualizado_em` mudou, exceto o das cobranças já resolvidas — paga ou isenta — cuja falta foi marcada.

## Resultado

- Migração `20261103012012_rpc_cobranca.sql` com `dar_baixa(cobranca)` e `isentar_cobranca(cobranca)`, que devolvem vazio, e três auxiliares em `privado`: `resolver_cobranca` (trava a cobrança, confere credor e encerramento e grava status e par), `primeiro_nome` e `resumo_cobranca`.
- **Ordem das checagens:** credor (`sem_permissao`, também para cobrança que não existe), jogo encerrado (`pagamento_nao_liberado`, também em jogo cancelado), já no status pedido (nada muda nem avisa) e cobrança fora de `pendente`/`comprovante_enviado` (`cobranca_resolvida`).
- **Textos:** título com o primeiro nome do credor; corpo "R$ 20,00 · Areia de Sábado, sáb 17 out", com o valor da cobrança e a data do início do jogo sem vírgula, e ". Nada a pagar." na isenção. `primeiro_nome` e `resumo_cobranca` servirão também ao `comprovante_recebido` do passo 6.
- **Âncora da retenção:** dentro da transação `now()` não anda, e toda escrita já marcaria `atualizado_em = now()`. Por isso o cenário recua um dia o `atualizado_em` das seis cobranças inativas, com o gatilho `tocar_atualizado_em` desligado só nesse `update`. Depois roda baixa e isenção em toda cobrança (pelo credor, pelo devedor e por um terceiro), as quatro edições, cancelar e encerrar, e confirmar e cancelar presença de cada participante. A cópia guardada tem de bater coluna a coluna. Por fim marca a falta de cada participante, e só mudam as inativas cuja participação virou `faltou`: as pagas e as isentas à mão. A cancelada no prazo e a multa isenta pela RN05 ficam. Uma cópia da suíte com um `update` neutro na cobrança cancelada falha, como deve.
- `comprovante_enviado` é gravado como postgres, porque o envio chega no passo 6.
- Códigos de recusa novos: `pagamento_nao_liberado`, `cobranca_resolvida`. Reaproveitado: `sem_permissao`.
- `rpc_cobranca.sql` com 42 asserções; `schema` 70, `rls` 69, `autenticacao` 39, `rpc_grupo` 63, `rpc_jogo` 164, `rpc_presenca` 126.

## Pronto quando

`supabase db reset` e as sete suítes imprimem `SUCESSO`.

## Commit

`Dá baixa e isenta cobrança, e confere a âncora da retenção`
