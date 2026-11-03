# Implementação — B · Jogos e presença

Onde o app diverge das imagens B1 a B7, ou completa o que elas não mostram. O PRD vence o design em comportamento ([DESIGN.md](../../DESIGN.md), Precedência); aqui fica o registro de cada caso.

Telas: ainda não implementadas (passo 5). As entradas abaixo vêm das decisões de produto de 2026-11-01, tomadas antes do passo 4.

## B4 — Cancelar fora do prazo

- **O texto da isenção muda.** A imagem diz "Se alguém da lista de espera pegar sua vaga, sua cobrança é isenta." Pela RN05, qualquer confirmação isenta uma multa, venha a pessoa da lista ou não, e na ordem de quem cancelou primeiro; então não há garantia de que a próxima confirmação isente esta. Texto do app: "Se outra pessoa confirmar presença depois de você, sua cobrança pode ser isenta."
- **O prazo exibido considera a remarcação.** "Sem multa" e "O prazo sem multa terminou…" mostram o prazo que vale, o mais tardio entre `inicio − prazo_cancelamento_horas` e `cancelamento_livre_ate` (RN02, RN20). Depois de uma remarcação, cancelar não gera multa até o início, e a B4 não abre nesse intervalo.

## B2 e B3 — Jogo

- **O recebedor que joga vê a B3 de qualquer confirmado, com dois ajustes** (RN07). Ele ocupa vaga e não tem cobrança; `cancelar_presenca` e `marcar_falta` já o tratam assim desde o passo 4 — cancelar não gera multa em hora nenhuma, e a falta dele só muda a participação. Decidido em 2026-11-03:
  - **O bloco "Sua parte" fica como está**, com o valor da vaga. Não é o que ele deve, e sim o que cada um paga: é a noção do rateio que ele precisa ter, e a F1 simplesmente não lista cobrança nenhuma dele.
  - **O bloco "Sem multa" também fica**, porque é o prazo que vale para a turma e ele é quem organiza. A **faixa abaixo vai para a terceira pessoa**: "Quem cancelar depois de qui, 16:30 mantém a cobrança.", no lugar de "Sem multa até qui, 16:30. Depois disso, cancelar mantém a cobrança."
  - **A B4 nunca abre para ele**, nem antes nem depois do prazo. "Cancelar presença" mostra uma confirmação curta, sem valor e sem prazo: "Cancelar sua presença? Você continua recebendo o rateio deste jogo."
- **O criador já nasce confirmado** (RN24): depois de criar o jogo, ele cai na B3, não na B2.
