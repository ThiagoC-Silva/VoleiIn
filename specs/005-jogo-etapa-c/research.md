# Research: etapa C da fatia 4

## R1. Ordem dos locks na saída do grupo (C16)

**Decisão:** `leave_group` e `remove_group_member` bloqueiam o grupo (como na fatia 3) e, em seguida, os jogos `open`/`confirmed` do grupo, em ordem de `id`, antes de ler passagens e espera. `join_game` bloqueia só o jogo e confere a filiação depois do lock. Se a entrada pegar o jogo primeiro, a saída espera o *commit* e enxerga a passagem nova, que é retirada; se a saída pegar primeiro, a entrada lê a filiação já apagada e recebe `NO_GAME_ACCESS`. A ordem grupo e depois jogo é a da etapa A, sem risco de *deadlock*.

## R2. Erro com `detail`

**Decisão:** `private.raise_error_detail(code, detail jsonb)` levanta `P0001` com `detail` em JSON (`docs/contratos-api.md`, seção 1). Os `game_ids` vêm em ordem de `id`.

## R3. Uma auxiliar para a saída e a remoção

**Decisão:** `private.leave_group_games(group, user)` faz a conferência da RN16 e os efeitos da RN14 e devolve `games_left`. As duas funções públicas mudam de corpo, com a mesma assinatura. Na remoção, a conferência vem depois de `TARGET_NOT_MEMBER`; na saída, depois de `LAST_ADMIN` (contrato).

## R4. Aviso à espera na saída do grupo

**Decisão:** um `waitlist_slot_opened` (`reason: slot_freed`) por jogo em que uma passagem foi retirada (`docs/contratos-api.md`, nota da seção 4), com a espera que restou.

## R5. W12 já verde

`get_profile_contact` já esconde o telefone oculto desde a etapa A. O W12 fica como regressão.
