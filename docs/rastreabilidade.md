# Rastreabilidade

Liga cada requisito funcional (RF) às regras (RN), à fatia, ao banco, às telas, aos testes e ao status (`plan-docs.md`, seção 5.4). Serve para responder "o que ainda não tem teste?".

- **Fonte:** os RFs vêm de `requisitos.md`, a fatia de `plano-implementacao.md` e as RNs da última coluna de `regras-negocio.md`. Os IDs de teste são os cenários de `testes-referencia.md`.
- **Preenchimento:** banco, telas e testes entram ao fechar cada fatia. As fatias ainda não feitas têm só RN e fatia.
- **Status:** *Pendente*; *Em andamento*, com parte do RF feita e testada numa etapa da fatia e o resto numa etapa seguinte; *Feito no local*, com os testes automáticos verdes e o fluxo conferido no emulador; *Falta Mxx*, à espera da conferência manual; *Concluído*, depois da conferência na produção (M03 e M04, na fatia 2).
- **Critério** (`plan-docs.md`, 5.4): nenhum RF sem fatia; nenhum RF concluído sem teste.

A fatia 1 (Fundação) não tem RF: ela entrega o schema, o RLS e o CI, cobertos por `supabase/tests/database/` e pelas seções 1 a 8 de `testes-referencia.md`.

**Fatia 2, em 13/11/2026:** RFs com testes automáticos verdes e L06 a L11 nas APIs 29 e 36. M01 e M02 conferidos no celular contra o Supabase local, e M03 e M04 na produção, em 13/11/2026. Os 16 RFs da fatia estão concluídos.

**Fatia 3, em 16/11/2026:** RFs com testes automáticos verdes e L12 a L14 nas APIs 29 e 36, com as migrações e a `preview-invite` na produção. M05 conferido no celular, com o build da produção, em 16/11/2026. Os 12 RFs da fatia estão concluídos. RF15 e RF16 cobrem o código de convite: abrir o convite por link fica para a fatia 8 (`plano-implementacao.md`). RF22 e RF102, os efeitos da saída do grupo sobre os jogos, ficam para a fatia 4.

**Fatia 4, etapa A, em 17/11/2026:** criar, ver e editar o jogo, entrar na lista e na espera. Testes automáticos verdes e L15 (sem o cancelamento) nas APIs 29 e 36, com as 4 migrações na produção. M06 conferido no celular, com o build da produção, em 17/11/2026, no Wi-Fi em vez do 4G (`specs/003-jogo-etapa-a/tasks.md`). Os RFs da etapa ficam *Em andamento* até a etapa C, que fecha a fatia com a saída, a espera, o cancelamento e os efeitos da saída do grupo (RF22, RF102).

| RF | Fatia | RN | Banco e serviços | Telas | Testes | Status |
|----|-------|----|------------------|-------|--------|--------|
| RF01 | 2 | — | Auth; `profiles`, `profile_private` (`on_auth_user_confirmed`) | `/signup` | S01, S02, L08 | Concluído |
| RF02 | 2 | — | Auth, código de 6 dígitos (ADR 0017, ADR 0018) | `/confirm-email` | S03 a S06, L08 | Concluído |
| RF03 | 2 | — | Auth, Google | `/login` | S07, M01 | Concluído |
| RF04 | 2 | — | Auth | `/login` | L01 a L03, L06 | Concluído |
| RF05 | 2 | — | Auth (sessão persistida) | Roteador | S10, L06 | Concluído |
| RF06 | 2 | — | Auth, código de recuperação | `/forgot-password` | S08, L09 | Concluído |
| RF07 | 2 | — | Auth | `/profile` | L07 | Concluído |
| RF08 | 2 | RN100 | `profiles.nickname`, `display_name` | `/profile/edit`, `/profile` | P02, S17, L10 | Concluído |
| RF09 | 2 | RN106 | `profiles.photo_path`; Storage `avatars` | `/profile/edit` | P05, P15, P16, A01 a A06, S12 | Concluído |
| RF10 | 2 | RN101 | `profile_private.phone`, `phone_visible` | `/profile/edit` | P08, S12, U03, U04, L10 | Concluído |
| RF11 | 2 | RN102, RN105 | `profile_private.pix_key_type`, `pix_key`; `private.is_valid_cpf`, `private.is_valid_cnpj` | `/profile/pix` | X01 a X14, U01, U02, U05, U06, S13 | Concluído |
| RF12 | 2 | RN105 | `profiles`, `profile_private`; `profile_private_guard_pix_key_removal` | `/profile/edit`, `/profile/pix` | P01 a P09, N01 a N09, S12, S13, L10 | Concluído |
| RF13 | 6 | RN65, RN103, RN104 | — | — | — | Pendente |
| RF14 | 3 | RN10, RN106 | `groups`, `group_members`; `create_group`; Storage `avatars` (`groups/<id>/`) | `/groups/new` | G01 a G03, S20, S21, L13 | Concluído |
| RF15 | 3 | RN11 | `groups.invite_code`; `regenerate_group_invite`, `invalidate_group_invite` | Sheet do convite em `/groups/:groupId` | G07 a G10, S27, S28, L13, M05 | Concluído |
| RF16 | 3 | RN12 | `group_join_requests`; `request_group_join`; Edge Function `preview-invite` | `/groups/join` | G11 a G14, Q01 a Q07, C13, S22 a S24, L12 | Concluído |
| RF17 | 3 | RN12, RN107 | `group_join_requests`; `decide_join_request`; leitura do perfil de quem pediu (RN107, exceção 2) | `/groups/:groupId/requests` | G15 a G18, C15, S32, L12 | Concluído |
| RF18 | 3 | RN106 | `update_group`; Storage `avatars` (`groups/<id>/`) | `/groups/:groupId/edit` | G04 a G06, A07, A08, A12, A13, S33 | Concluído |
| RF19 | 3 | RN107 | `group_members`; leitura de `profiles` por `private.shares_context` | `/groups/:groupId/members`, `/people/:userId` | K02, K07, S29, S30, S34, L12 | Concluído |
| RF20 | 3 | RN14 | `remove_group_member` | `/groups/:groupId/members` | G27 a G29, S31 | Concluído |
| RF21 | 3 | RN14 | `leave_group` | `/groups/:groupId` | G23, G26, K03, S26, L12 | Concluído |
| RF22 | 4 | RN14, RN16, RN65 | — | — | — | Pendente |
| RF23 | 3 | RN10 | `set_group_role` | `/groups/:groupId/members` | G19, G21, G22, S29, S31, L14 | Concluído |
| RF24 | 3 | RN13 | `set_group_role`, `leave_group`; invariante de admin da fatia 1 | `/groups/:groupId`, `/groups/:groupId/members` | G20, G24, G25, S26, S31 | Concluído |
| RF25 | 3 | — | `group_members`; leitura de `groups` pelo membro | `/groups` | K01, S18, S19 | Concluído |
| RF26 | 4 | RN06, RN15, RN20, RN21, RN23 | `games`; `create_game` | `/games/new`, `/groups/:groupId` | J01, J02, J05 a J08, S39 a S41, L15 | Em andamento |
| RF27 | 4 | RN20 | `create_game` (sem rascunho) | `/games/new` | J01, J02, J05 a J08, S39 a S41, L15 | Em andamento |
| RF28 | 4 | RN23 | `games.location_name`, `maps_url` | `/games/new`, `/games/:gameId` | J01, J02, J05 a J08, S39 a S41, L15 | Em andamento |
| RF29 | 4 | RN05, RN24 | `games.total_cents`; estimativa no app (RN05) | `/games/new` | J07, U09, U11, S41 | Em andamento |
| RF30 | 4 | RN23 | `games.starts_at`, `ends_at`, `cancellation_deadline` | `/games/new` | J01, J02, J05 a J08, S39 a S41, L15 | Em andamento |
| RF31 | 4 | RN21, RN28 | `game_admins` (criador) | `/games/new` | J01, J04, S38 | Em andamento |
| RF32 | 4 | RN22, RN28 | `games.receiver_id` | `/games/new` | J01, J04, S38 | Em andamento |
| RF33 | 5 | RN29, RN30, RN31, RN94, RN115 | — | — | — | Pendente |
| RF34 | 4 | RN15, RN25, RN27 | — | — | — | Pendente |
| RF35 | 4 | RN16, RN25, RN26 | — | — | — | Pendente |
| RF36 | 4 | RN33, RN34, RN35 | `update_game` | `/games/:gameId/edit` | J09 a J13, S53 | Em andamento |
| RF37 | 4 | RN40 | `games.slot_limit`; `game_limit_history` | `/games/new` | J03, O01, O02, O20, O21 | Em andamento |
| RF38 | 4 | RN41, RN42 | `join_game` (limite) | `/games/:gameId` | J03, O01, O02, O20, O21 | Em andamento |
| RF39 | 4 | RN43 | — | — | — | Pendente |
| RF40 | 5 | RN34, RN36, RN44, RN46, RN47, RN70 | — | — | — | Pendente |
| RF41 | 5 | RN34, RN48, RN74 | — | — | — | Pendente |
| RF42 | 5 | RN45, RN46, RN49 | — | — | — | Pendente |
| RF43 | 8 | RN55 | — | — | — | Pendente |
| RF44 | 4 | — | `can_view_game`; RLS de `games` | `/games`, `/games/:gameId` | W01 a W04, W13, W14, S36, S37, S50 | Em andamento |
| RF45 | 4 | RN102 | `get_profile_contact` (chave Pix) | `/games/:gameId` | W08 a W11, S42, S44 | Em andamento |
| RF46 | 4 | RN52, RN107 | RLS de `game_participants`, `game_waitlist`; Realtime | `/games/:gameId` | W01 a W04, W13, W14, S36, S37, S50 | Em andamento |
| RF47 | 4 | RN50 | `join_game`; `game_participants` | `/games/:gameId` | O01 a O07, T03 a T05, S42 | Em andamento |
| RF48 | 8 | RN50, RN107 | — | — | — | Pendente |
| RF49 | 4 | RN51, RN54 | `join_waitlist`; `game_waitlist` (só a entrada) | `/games/:gameId` | O03, O04, T05 | Em andamento |
| RF50 | 4 | RN02, RN29, RN56, RN57 | — | — | — | Pendente |
| RF51 | 4 | RN53 | `join_game` com trava por jogo (RN53) | `/games/:gameId` | C01, C02, C04, C05 | Em andamento |
| RF52 | 4 | RN42, RN53, RN59 | `set_slot_limit` | `/games/:gameId/edit` | O20 a O23, C05, S53 | Em andamento |
| RF53 | 4 | RN33, RN41, RN59 | `set_slot_limit` (redução) | `/games/:gameId/edit` | O20 a O23, C05, S53 | Em andamento |
| RF54 | 4 | RN29, RN58 | — | — | — | Pendente |
| RF55 | 4 | RN02, RN03, RN51 | `join_game` (prazo e início, RN03) | `/games/:gameId` | O01 a O07, T03 a T05, S42 | Em andamento |
| RF56 | 5 | RN02, RN03, RN35, RN57, RN60 | — | — | — | Pendente |
| RF57 | 5 | RN03, RN56, RN61 | — | — | — | Pendente |
| RF58 | 5 | RN62 | — | — | — | Pendente |
| RF59 | 5 | RN58, RN65 | — | — | — | Pendente |
| RF60 | 5 | RN47, RN63 | — | — | — | Pendente |
| RF61 | 5 | RN63 | — | — | — | Pendente |
| RF62 | 5 | RN64 | — | — | — | Pendente |
| RF63 | 5 | RN65 | — | — | — | Pendente |
| RF64 | 5 | RN36, RN66, RN93 | — | — | — | Pendente |
| RF65 | 5 | — | — | — | — | Pendente |
| RF66 | 5 | RN67, RN70 | — | — | — | Pendente |
| RF67 | 5 | RN04, RN71, RN75 | — | — | — | Pendente |
| RF68 | 5 | RN72 | — | — | — | Pendente |
| RF69 | 5 | RN72 | — | — | — | Pendente |
| RF70 | 5 | RN72 | — | — | — | Pendente |
| RF71 | 5 | RN32, RN72, RN73 | — | — | — | Pendente |
| RF72 | 5 | RN73 | — | — | — | Pendente |
| RF73 | 5 | RN76 | — | — | — | Pendente |
| RF74 | 5 | RN76 | — | — | — | Pendente |
| RF75 | 5 | — | — | — | — | Pendente |
| RF76 | 5 | — | — | — | — | Pendente |
| RF77 | 6 | RN102 | — | — | — | Pendente |
| RF78 | 6 | RN86, RN87 | — | — | — | Pendente |
| RF79 | 6 | — | — | — | — | Pendente |
| RF80 | 6 | RN32, RN88 | — | — | — | Pendente |
| RF81 | 6 | RN89 | — | — | — | Pendente |
| RF82 | 6 | RN80 | — | — | — | Pendente |
| RF83 | 6 | RN81, RN82, RN83 | — | — | — | Pendente |
| RF84 | 6 | RN84 | — | — | — | Pendente |
| RF85 | 6 | RN85 | — | — | — | Pendente |
| RF86 | 6 | RN90 | — | — | — | Pendente |
| RF87 | 6 | RN91, RN92 | — | — | — | Pendente |
| RF88 | 7 | RN110 | — | — | — | Pendente |
| RF89 | 7 | — | — | — | — | Pendente |
| RF90 | 7 | RN53 | — | — | — | Pendente |
| RF91 | 7 | RN114 | — | — | — | Pendente |
| RF92 | 7 | RN111, RN112 | — | — | — | Pendente |
| RF93 | 7 | RN111, RN112 | — | — | — | Pendente |
| RF94 | 7 | RN111 | — | — | — | Pendente |
| RF95 | 7 | — | — | — | — | Pendente |
| RF96 | 7 | RN01, RN113 | — | — | — | Pendente |
| RF97 | 7 | RN115 | — | — | — | Pendente |
| RF98 | 7 | RN110 | — | — | — | Pendente |
| RF99 | 7 | RN110 | — | — | — | Pendente |
| RF100 | 7 | RN52 | — | — | — | Pendente |
| RF101 | 4 | RN101, RN107 | — | — | — | Pendente |
| RF102 | 4 | RN16 | — | — | — | Pendente |
| RF103 | 3 | RN13, RN17 | `archive_group` | `/groups/:groupId/edit` | G30 a G33, K04, S33, L13 | Concluído |
| RF104 | 7 | RN17, RN58, RN66, RN80 | — | — | — | Pendente |
| RF105 | 2 | — | `terms_acceptances`; `current_terms_versions()` | `/terms`, `/terms/:document` | P10 a P14, S09, S10, L08 | Concluído |
| RF106 | 2 | — | Auth, código no endereço novo | `/profile/email` | S11, S14, L11 | Concluído |
| RF107 | 2 | — | Auth | `/profile/password` | S11, S15 | Concluído |
| RF108 | 2 | — | Auth, vinculação de identidades | `/login`, `/profile` | U07, S11, M02 | Concluído |
