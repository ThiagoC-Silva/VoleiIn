-- Fatia 3 - Grupos. Leitura de groups, group_members, group_join_requests e
-- leitura de profiles por contexto.
-- Documentos: docs/rls-matriz.md (fatia 3), cenários B03, B04 e K01 a K15 de
-- docs/testes-referencia.md.
--
-- O membro lê o próprio grupo e os integrantes; o admin lê também as
-- solicitações do grupo; quem pediu lê só as próprias. Sem insert, update e
-- delete: toda escrita em grupo passa pelas funções do contratos-api.md (seção 3).
-- profiles não ganha privilégio novo: o select da fatia 2 cobre todas as
-- colunas, e as políticas abaixo decidem as linhas.

-- Privilégios ----------------------------------------------------------------
grant select on public.groups to authenticated;
grant select on public.group_members to authenticated;
grant select on public.group_join_requests to authenticated;

-- groups e group_members -----------------------------------------------------
-- O membro lê invite_code: todo membro vê e compartilha o código (telas.md, 6.5).
-- Grupo arquivado não tem membros, então ninguém o lê.
create policy groups_select_member on public.groups
for select to authenticated
using (private.is_group_member(id, (select auth.uid())));

create policy group_members_select_member on public.group_members
for select to authenticated
using (private.is_group_member(group_id, (select auth.uid())));

-- group_join_requests --------------------------------------------------------
create policy group_join_requests_select_own on public.group_join_requests
for select to authenticated
using (user_id = (select auth.uid()));

create policy group_join_requests_select_admin on public.group_join_requests
for select to authenticated
using (private.is_group_admin(group_id, (select auth.uid())));

-- profiles -------------------------------------------------------------------
-- RN107: quem compartilha contexto. Inclui o perfil anonimizado (RN104, fatia 6).
create policy profiles_select_context on public.profiles
for select to authenticated
using (private.shares_context((select auth.uid()), id));

-- RN107, exceção 2: o admin vê quem tem solicitação pendente no grupo dele,
-- só enquanto ela está pending.
create policy profiles_select_join_requester on public.profiles
for select to authenticated
using (private.has_pending_join_request(id, (select auth.uid())));
