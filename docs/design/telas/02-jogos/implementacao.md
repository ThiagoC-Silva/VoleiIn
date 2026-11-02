# Implementação — B · Jogos e presença

Onde o app diverge das imagens B1 a B7, ou completa o que elas não mostram. O PRD vence o design em comportamento ([DESIGN.md](../../DESIGN.md), Precedência); aqui fica o registro de cada caso.

Telas: ainda não implementadas (passo 5). As entradas abaixo vêm das decisões de produto de 2026-11-01, tomadas antes do passo 4.

## B4 — Cancelar fora do prazo

- **O texto da isenção muda.** A imagem diz "Se alguém da lista de espera pegar sua vaga, sua cobrança é isenta." Pela RN05, qualquer confirmação isenta uma multa, venha a pessoa da lista ou não, e na ordem de quem cancelou primeiro; então não há garantia de que a próxima confirmação isente esta. Texto do app: "Se outra pessoa confirmar presença depois de você, sua cobrança pode ser isenta."
- **O prazo exibido considera a remarcação.** "Sem multa" e "O prazo sem multa terminou…" mostram o prazo que vale, o mais tardio entre `inicio − prazo_cancelamento_horas` e `cancelamento_livre_ate` (RN02, RN20). Depois de uma remarcação, cancelar não gera multa até o início, e a B4 não abre nesse intervalo.

## B2 e B3 — Jogo

- **Aberto: o recebedor que joga não tem cobrança** (RN07). O desenho mostra "Sua parte" para quem confirmou, e não há versão para o recebedor confirmado, que não deve nada. Decidir o que o bloco mostra antes de implementar a B3 no passo 5.
- **O criador já nasce confirmado** (RN24): depois de criar o jogo, ele cai na B3, não na B2.
