# T03 — `rpc_grupo` e a base das funções

**Estado:** a fazer · **Depende de:** T02

## Objetivo

Criar as funções de grupo — que vêm primeiro para os cenários seguintes criarem grupos pelo caminho real (`docs/stack.md`, passo 4) — e as peças que todas as funções do passo reaproveitam: o gravador de avisos, a convenção de recusa e o arnês das suítes de cenário.

## O que já existe

- Tabelas `grupo` e `membro_grupo` (`grupo.criado_por`, `membro_grupo.papel` `admin`/`membro`, unicidade `membro_grupo_grupo_pessoa_unico`).
- `privado.eh_membro` e `privado.eh_admin`.
- O arnês de `supabase/testes/rls.sql`.
- As seis cores de grupo em `docs/design/DESIGN.md` (Cor do grupo): `#3B6FE0`, `#0FA3A0`, `#7B5CE6`, `#E0559B`, `#7FB22A`, `#5A6B8C`.
- Os textos aprovados de `regra_grupo_alterada`, `promovido_a_admin` e `removido_do_grupo` (T01).

## O que falta

- [ ] `supabase migration new rpc_grupo`, com:
  - `privado.avisar(p_pessoa, p_tipo, p_titulo, p_corpo, p_jogo, p_cobranca)` — insere em `notificacao`;
  - `criar_grupo(nome, cor, prazo_cancelamento_horas, local_padrao_id, vagas_padrao, custo_total_padrao)` → `uuid`: nome não vazio, cor entre as seis, prazo não negativo; quem chama entra em `membro_grupo` como `admin` (RF03, RN12, RN13);
  - `editar_grupo(grupo, ...)`: só admin (RN13); grava os campos; se `prazo_cancelamento_horas` mudou, avisa `regra_grupo_alterada` a cada confirmado de jogo `aberto` do grupo com `jogo.prazo_cancelamento_horas` vazio (RN11). Outras mudanças não avisam;
  - `promover_admin(grupo, pessoa)`: só admin; alvo precisa ser membro; `membro` → `admin`, avisando `promovido_a_admin`; já admin, nada muda;
  - `remover_membro(grupo, pessoa)`: só admin; não remove a si mesmo (o caminho é `sair_grupo`); apaga a linha de `membro_grupo` e avisa `removido_do_grupo`. Participações e cobranças ficam (RN30);
  - `sair_grupo(grupo)`: o membro apaga a própria linha; admin único com outros membros é recusado (`promova_outro_admin`); o último membro sai livre;
  - `grant execute` das cinco a `authenticated`; nenhum para `privado.avisar`.
- [ ] Códigos de recusa: `nome_vazio`, `cor_invalida`, `prazo_invalido`, `nao_e_membro`, `promova_outro_admin`, `sem_permissao` (42501).
- [ ] `supabase/CLAUDE.md`, seção Funções: a convenção de recusa (README, Recusa) e a de `privado.avisar`.
- [ ] `supabase/testes/rpc_grupo.sql`, com o arnês e `espera_recusa`:
  - criar: quem cria é admin; cor fora das seis e prazo negativo recusados;
  - editar: membro comum recusado; admin edita; mudança de cor não grava aviso;
  - promover: admin promove membro e o aviso nasce para o promovido; não membro recusado; repetição não duplica aviso;
  - remover: membro comum não remove; admin remove e o removido recebe aviso; remover a si mesmo recusado;
  - sair: admin único com outro membro recusado; depois de promover, sai; último membro sai;
  - `anon` não executa nenhuma; `authenticated` não executa `privado.avisar`.
- [ ] O aviso de `editar_grupo` sobre o prazo depende de confirmados em jogo: a asserção entra na T05.

## Pronto quando

`supabase db reset` e as quatro suítes — `schema`, `rls`, `autenticacao` e `rpc_grupo` — imprimem `SUCESSO`.

## Commit

`Cria as funções de grupo e o gravador de avisos`
