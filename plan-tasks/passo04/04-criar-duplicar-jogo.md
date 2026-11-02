# T04 — `rpc_jogo`: criar e duplicar jogo

**Estado:** a fazer · **Depende de:** T03

## Objetivo

Criar jogo de grupo e avulso (RF07, RF08) e duplicar jogo (RF34), com as checagens da RN15 no banco, a chave do recebedor (RN24), o preço por vaga (RN01, RN16) e o criador nascendo confirmado. Esta task cria a migração `rpc_jogo` e as auxiliares que presença e edição reaproveitam.

## O que já existe

- `jogo` com `jogo_preco_por_vaga_arredondado`, `jogo_avulso_tem_prazo` e `jogo_chave_pix_recebedor_nao_vazia`; `cancelamento_livre_ate` (T02).
- `privado.conhece`, `privado.eh_membro`, `privado.avisar`.
- Locais do seed (README, Testes), com faixa de sábado atravessando a meia-noite na Arena e `fecha = 00:00` na sexta do Ginásio.

## O que falta

- [ ] `supabase migration new rpc_jogo`, com as auxiliares em `privado`:
  - `prazo_sem_multa(jogo)` → `timestamptz`: o mais tardio entre `inicio − prazo` (do jogo, ou do grupo quando vazio) e `cancelamento_livre_ate` (RN02, RN20);
  - `checar_rn15(local, quadra, inicio, duracao, jogo_ignorado)`:
    - `por_quadra` exige quadra do próprio local; `por_horario` exige quadra vazia;
    - `por_quadra`: nenhum jogo `aberto` ou `encerrado` na mesma quadra com intervalo sobreposto (`quadra_ocupada`);
    - `por_horario` com `capacidade`: o pico de jogos simultâneos dentro do intervalo, contando o novo, não passa da capacidade (`local_lotado`); capacidade vazia não checa;
    - o intervalo inteiro, em Brasília, cabe numa faixa de `horario_funcionamento`, inclusive a que atravessa a meia-noite (`fecha <= abre`) e a que fecha à meia-noite (`fora_do_funcionamento`);
    - `jogo_ignorado` exclui o próprio jogo, para a remarcação da T07;
  - `nascer_cobranca(participacao)`: cobrança `pendente`, origem `parte`, valor `preco_por_vaga`, credor o recebedor — nunca para o recebedor (o `check` da T02 garante); se a participação já tem cobrança, reabre a mesma (RN25).
- [ ] `criar_jogo(grupo, local, quadra, inicio, duracao_minutos, vagas_total, custo_total, prazo_cancelamento_horas, recebedor, chave_pix_recebedor)` → `uuid`:
  - grupo: quem chama é membro (RN13); avulso: qualquer pessoa, prazo obrigatório (RN12);
  - `inicio` no futuro (`inicio_no_passado`); vagas e duração positivas, custo não negativo;
  - recebedor: quem chama, por padrão, ou alguém que ele `conhece`; a chave é a digitada, ou a do perfil do recebedor; nenhuma das duas recusa (`recebedor_sem_chave`, RN24);
  - `pg_advisory_xact_lock` com o `local_id`, depois `checar_rn15`;
  - `preco_por_vaga = (custo + vagas − 1) / vagas`, status `aberto`;
  - o criador nasce `confirmado`, com `confirmado_em = now()`; cobrança só se ele não for o recebedor (RN07, RN24).
- [ ] `duplicar_jogo(origem, inicio, chave_pix_recebedor)` → `uuid` (RN28): grupo, qualquer membro; avulso, só o criador da origem; copia local, quadra, duração, vagas, custo, recebedor e prazo; a chave é relida do perfil do recebedor ou digitada; mesmas checagens; quem duplica é o criador do jogo novo e nasce confirmado.
- [ ] `grant execute` das duas a `authenticated`.
- [ ] `supabase/testes/rpc_jogo.sql`:
  - preço: 10000 em 7 vagas dá `1429`; 10000 em 10 dá `1000`;
  - criador recebedor nasce confirmado sem cobrança; criador com outro recebedor nasce com cobrança de `parte`;
  - recebedor sem chave e sem chave digitada recusado; chave digitada não altera o perfil de ninguém;
  - recebedor que o criador não conhece recusado;
  - não membro cria no grupo: recusado; avulso sem prazo: recusado; início no passado: recusado;
  - RN15: mesma quadra e horário sobreposto recusado; quadra vizinha passa; jogo cancelado não ocupa; Ginásio aceita dois simultâneos e recusa o terceiro; fora da faixa recusado; jogo das 23h à 1h de sábado na Arena passa; das 22h às 0h de sexta no Ginásio passa;
  - duplicar: membro duplica jogo do grupo; não criador duplica avulso recusado; chave vem do perfil atual, não da origem; nenhuma participação copiada além do criador novo.

## Pronto quando

`supabase db reset` e as cinco suítes (`schema`, `rls`, `autenticacao`, `rpc_grupo`, `rpc_jogo`) imprimem `SUCESSO`.

## Commit

`Cria e duplica jogos com as checagens de quadra e funcionamento`
