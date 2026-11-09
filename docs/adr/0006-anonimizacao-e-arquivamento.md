# 0006. Anonimização de contas e arquivamento de grupos

- **Status:** Aceito
- **Data:** 2026-11-06

## Contexto
Quem exclui a conta ou o grupo tem histórico de jogos, multas, valores e comprovantes ligado a outras pessoas. Apagar as linhas quebraria o rateio e o histórico de quem continua no app. A LGPD exige que os dados pessoais deixem de existir.

## Decisão
A conta excluída é **anonimizada**: nome, apelido, foto, telefone, chave Pix e e-mail são apagados, e o histórico fica ligado a um perfil anônimo (RF13, RN104, `stacks.md` 13.2). O grupo excluído é **arquivado**: membros e solicitações saem, o convite é invalidado e os jogos encerrados continuam no histórico (RF103, RN17).

## Alternativas descartadas
- **Exclusão física em cascata:** apagaria valores e multas de outras pessoas e quebraria o rateio de jogos concluídos.
- **Exclusão lógica sem anonimizar:** manteria dados pessoais de quem pediu para sair.

## Consequências
- `auth.users` não é apagado, e `profiles` usa `on delete restrict` (`modelo-dados.md`, seção 9).
- A exclusão tem bloqueios (RN103) e roda numa transação única, com auditoria sem dados pessoais.
