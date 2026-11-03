# Implementação — G · Avisos

Onde o app diverge da imagem G1, ou completa o que ela não mostra. O PRD vence o design em comportamento ([DESIGN.md](../../DESIGN.md), Precedência); aqui fica o registro de cada caso.

Tela: ainda não implementada (passo 7). Os avisos, porém, são gravados desde o passo 4, cada um pela função que muda o estado, na mesma transação ([`docs/stack.md`](../../../stack.md), Onde cada regra mora). Este arquivo é a fonte do título, do corpo e dos destinatários de cada tipo de `notificacao_tipo`: o G1 mostra 5 deles, e os outros 9 foram escritos no mesmo tom e aprovados em 2026-11-02, antes de qualquer função gravá-los.

## Convenções dos textos

- **O jogo** aparece pelo nome do grupo, como no G1 ("Areia de Sábado"). No jogo avulso, que não tem grupo, pelo nome do local ("Arena Beira-Mar"). Abaixo, `{jogo}`.
- **Data e hora** em horário de Brasília, nos formatos do `DESIGN.md`: `sáb, 24 out · 20:00`. Abaixo, `{data}` é a data curta do início do jogo e `{hora}` a hora dele.
- **Dinheiro** sempre com centavos: `R$ 20,00`.
- **Pessoas:** no título, o primeiro nome ("Diego enviou um comprovante"); no corpo, o nome inteiro ("R$ 20,00 para Ana Souza"), como no G1. Primeiro nome é a primeira palavra de `pessoa.nome`.
- **Quem faz o ato não recebe o aviso dele.** Se o criador remarca o jogo em que está confirmado, os outros confirmados recebem o `jogo_editado`; ele, não.
- **Repetir a operação não repete o aviso** (RNF10): a função só avisa quando o estado de fato muda.
- Tudo é formatado no banco, na gravação; o app só exibe `titulo` e `corpo`.

## Tipos

`jogo` e `cobranca` dizem qual referência a linha leva, e é para lá que o toque no aviso leva.

| Tipo | Título | Corpo | Destinatários | Grava | Leva a |
| --- | --- | --- | --- | --- | --- |
| `vaga_liberada` (G1) | Abriu uma vaga em `{jogo}` | `{data}` · `{hora}`. Fica com quem confirmar primeiro. | Todos em `lista_espera` do jogo (RN08) | `cancelar_presenca`, quando sai um confirmado e a fila não está vazia; `editar_jogo`, quando as vagas aumentam com fila | jogo |
| `jogo_editado` | Jogo remarcado | `{jogo}` de `{data antiga}` passou para `{data}` · `{hora}`, em `{local}`. Cancelar fica sem multa até o início. | Os confirmados (RN20) | `editar_jogo`, na remarcação: data, horário, local ou quadra | jogo |
| `jogo_editado` (multa cancelada) | Jogo remarcado | `{jogo}` de `{data antiga}` passou para `{data}` · `{hora}`, em `{local}`. Sua multa de R$ 20,00 foi cancelada. | Quem teve a multa de `cancelamento_tardio` cancelada pela remarcação (RN20) | `editar_jogo`, na remarcação | jogo |
| `jogo_cancelado` | Jogo cancelado | `{jogo}`, `{data}` · `{hora}`, não vai acontecer. Nada a pagar por ele. | Os confirmados, a lista de espera e quem tinha multa ativa (RN23) | `cancelar_jogo` | jogo |
| `regra_grupo_alterada` | Novo prazo sem multa em `{grupo}` | Agora são 6 h antes do início. No jogo de `{data}` · `{hora}`, cancelar sem multa vai até sex, 23 out · 14:00. Com prazo de 1 h: "Agora é 1 h antes do início. No jogo de …", com o mesmo resto. Com prazo zero: "Agora dá para cancelar sem multa até o início do jogo, `{data}` · `{hora}`." | Os confirmados de cada jogo afetado: jogo do grupo, `aberto`, ainda não começado, sem prazo próprio, cujo prazo sem multa de fato mudou (RN11). Um aviso por jogo | `editar_grupo`, quando `prazo_cancelamento_horas` muda | jogo |
| `valor_recalculado` (G1) | `{jogo}` mudou o custo | Total R$ 300,00. Sua parte passou para R$ 21,43. | Os confirmados com cobrança ativa, quando o valor por vaga muda (RN01) | `editar_jogo`, quando muda `custo_total` | cobrança |
| `valor_recalculado` (vagas) | `{jogo}` mudou as vagas | Agora são 14 vagas. Sua parte passou para R$ 21,43. | Idem | `editar_jogo`, quando muda só `vagas_total` | cobrança |
| `valor_recalculado` (os dois) | `{jogo}` mudou o custo e as vagas | Total R$ 300,00 em 14 vagas. Sua parte passou para R$ 21,43. | Idem | `editar_jogo`, quando mudam os dois | cobrança |
| `valor_recalculado` (multa) | Os três títulos acima | O mesmo começo, terminando em "Sua multa passou para R$ 21,43." | Quem tem multa de `cancelamento_tardio` `pendente` no jogo | `editar_jogo` | cobrança |
| `pagamento_liberado` (G1) | Pagamento liberado | R$ 20,00 para Ana Souza. Vence dom, 18 out · 23:00. | Cada devedor com cobrança `pendente` no encerramento; não o recebedor, nem isentos, nem a lista de espera (RN07) | `privado.encerrar`, chamada por `encerrar_jogo` e pela rotina de minuto | cobrança |
| `cobranca_vencida` (G1) | Cobrança vencida | R$ 20,00 para Ana Souza · `{jogo}` | O devedor de cobrança ainda `pendente` no vencimento; quem já enviou comprovante não recebe (RN07, RN26) | Rotina de minuto (passo 8) | cobrança |
| `comprovante_recebido` (G1) | Diego enviou um comprovante | R$ 21,43 · `{jogo}`, qui 15 out | O credor (RN09) | `enviar_comprovante` (passo 6) | cobrança |
| `comprovante_recusado` | Comprovante já usado | Esse comprovante já foi usado em outra cobrança. Envie o de R$ 20,00 para Ana Souza · `{jogo}`. | O devedor que tentou o envio (RN10) | `enviar_comprovante` (passo 6) | cobrança |
| `cobranca_confirmada` | Ana confirmou seu pagamento | R$ 20,00 · `{jogo}`, sáb 17 out | O devedor (RF22) | `dar_baixa` | cobrança |
| `cobranca_isenta` (manual) | Ana isentou sua cobrança | R$ 20,00 · `{jogo}`, sáb 17 out. Nada a pagar. | O devedor (RF23) | `isentar_cobranca` | cobrança |
| `cobranca_isenta` (automática) | Multa isenta | Outra pessoa confirmou presença em `{jogo}`, `{data}`. Os R$ 20,00 da sua multa não são mais devidos. | O cancelante tardio isento (RN05) | `confirmar_presenca`, pela função interna que a `aplicar_convite` também chama | cobrança |
| `falta_marcada` | Falta marcada | Ana marcou sua falta em `{jogo}`, sáb 17 out. O valor da cobrança não muda. | Quem foi marcado (RN04) | `marcar_falta` | cobrança |
| `falta_marcada` (recebedor) | Falta marcada | Ana marcou sua falta em `{jogo}`, sáb 17 out. | O recebedor confirmado marcado como faltoso, que não tem cobrança (RN04, RN07) | `marcar_falta` | jogo |
| `removido_do_grupo` | Você não está mais em `{grupo}` | Um admin removeu você do grupo. Suas presenças e cobranças continuam valendo. | Quem foi removido (RN30) | `remover_membro` | — |
| `promovido_a_admin` | Você agora é admin de `{grupo}` | Bruno promoveu você. Agora você edita as regras, convida e remove membros. | Quem foi promovido (RN13) | `promover_admin` | — |

## Notas

- **Títulos em frase nominal** ("Jogo remarcado", "Jogo cancelado", "Falta marcada") seguem os do G1 ("Cobrança vencida", "Pagamento liberado"). Evitam pôr `{jogo}` como sujeito, que no avulso daria "Arena Beira-Mar foi remarcado". A exceção é o `valor_recalculado`, que vem do G1: no avulso, fica "Arena Beira-Mar mudou o custo".
- **`jogo_editado` identifica o jogo pelo que ele era**: `{jogo}` e `{data antiga}` são os de antes da remarcação, porque é por eles que a pessoa o conhece; `{local}` é o novo, com a quadra quando houver ("Arena Beira-Mar · Quadra 2"). Quem é confirmado e também teve a multa cancelada não existe: a multa é de quem cancelou.
- **Remarcação com mudança de custo ou de vagas** no mesmo pedido grava os dois avisos, um de cada tipo.
- **`valor_recalculado` sem mudança no valor por vaga** não avisa: custo de R$ 100,00 para R$ 100,01 em 7 vagas mantém R$ 14,29, e nenhuma cobrança muda.
- **`regra_grupo_alterada` com 1 h e com zero** (aprovado em 2026-11-02): "são 1 h" e "são 0 h" soariam errados. Com 1 h, o verbo vai ao singular. Com zero, o prazo sem multa é o próprio início, e a segunda frase só repetiria a data; o corpo vira uma frase só.
- **Pessoa no corpo com o nome inteiro**, também no `promovido_a_admin` (confirmado em 2026-11-02): "Ana Souza promoveu você." O "Bruno" da tabela é o exemplo de um nome de uma palavra.
- **`valor_recalculado` com 1 vaga** segue a variação do `regra_grupo_alterada`: "Agora é 1 vaga." e "Total R$ 30,00 em 1 vaga.". Como nos outros avisos da edição, `{jogo}` é o nome de antes dela.
- **`regra_grupo_alterada` sem efeito não avisa.** Num jogo remarcado, `cancelamento_livre_ate` é o próprio início, e mudar o prazo do grupo não muda o prazo sem multa dele (RN02); num jogo que já começou, cancelar não é mais possível.
- **`comprovante_recusado` no passo 6.** Se a recusa do envio for uma exceção, a transação desfaz também a linha do aviso. O passo 6 decide entre devolver a recusa sem exceção, gravando o aviso, e não gravar o aviso, já que a F4 mostra a recusa na hora.
- **`falta_marcada` do recebedor** (decidido em 2026-11-02): o recebedor confirmado que não aparece também leva falta, mas não tem cobrança. O aviso perde a frase do valor e leva ao jogo.
- **`pagamento_liberado` não vai a quem encerra à mão** (decidido em 2026-11-02), pela convenção de quem faz o ato: o criador que encerra e deve a parte dele vê o débito no painel e recebe o `cobranca_vencida` se não pagar. No encerramento pela rotina de minuto, não há autor, e todo devedor com cobrança `pendente` recebe.
- **Data sem vírgula depois do `{jogo}`**: nos textos com "`{jogo}`, sáb 17 out" (`comprovante_recebido`, `cobranca_confirmada`, `cobranca_isenta` manual, `falta_marcada`), a data curta perde a vírgula do dia da semana, como no G1 ("Vôlei de Quinta, qui 15 out"), para não ficar "Areia de Sábado, sáb, 17 out". É a data do início do jogo.
- **Ícone e cor** de cada tipo ficam para o passo 7, com a tela. Os cinco do G1 já têm os seus.
