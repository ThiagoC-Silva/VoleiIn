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

**Fatia 4, em 18/11/2026:** etapas B (saídas, remoção e espera) e C (admins do jogo, cancelamento, saída do grupo com jogos e telefone visível) com testes automáticos verdes e L15 a L19 nas APIs 29 e 36, e as migrações das três etapas na produção (`setup.md`, 9.6 a 9.8). M07 conferido no celular em 18/11/2026: **Abrir no Maps** com o build da produção, e **Ligar** e **WhatsApp** com o build do Supabase local (`env/device.json`), porque a produção só tem uma conta e o próprio perfil não abre pela interface. Os 27 RFs da fatia estão concluídos.

**Fatia 5, etapa A, em 18/11/2026:** conclusão manual e automática e rateio. Testes automáticos verdes e L20 nas APIs 29 e 36, com as 2 migrações na produção (`setup.md`, 9.9). Os RFs da etapa ficam *Em andamento* até a etapa C, que fecha a fatia: as faltas, as multas e as isenções (RF60 a RF63, RF69, RF70) entram na etapa B, e a troca de recebedor (RF33) e as Cobranças (RF75, RF76) na etapa C. O RF42 espera o M08 na produção.

**Fatia 5, etapa B, em 18/11/2026:** faltas, multas e isenções, automática e manual, e o histórico da pessoa no jogo. Testes automáticos verdes e L21 nas APIs 29 e 36, com a migração `create_waive_penalty` na produção (`setup.md`, 9.10). Os RFs da etapa (RF56 a RF65, RF69, RF70) ficam *Em andamento* até a etapa C, que fecha a fatia.

**Fatia 5, em 24/11/2026:** etapa C (troca de recebedor e Cobranças) com testes automáticos verdes e L22 nas APIs 29 e 36, e as migrações das três etapas na produção (`setup.md`, 9.9 a 9.11). M08 conferido no banco da produção em 24/11/2026. Os 25 RFs da fatia estão concluídos.

**Fatia 6, etapa B, sessão 2 (servidor), em 25/11/2026:** `record_receipt`, `review_receipt`, a leitura de `receipts`, o bucket e a Edge Function `process-receipt`, com o conjunto fixo CF01 a CF26 e a medição com a API real, que escolheu o `claude-haiku-5-5` (`comprovantes-ia.md`, seção 9). RF78 a RF83 e RF86 ficam *Em andamento* até as telas (sessão 3) e a validação (sessão 4).

**Fatia 6, etapa A, em 25/11/2026:** valor a pagar com a chave Pix, marcar como pago e reverter. Testes automáticos verdes e L23 nas APIs 29 e 36, com a migração `create_manual_payment` na produção (`setup.md`, 9.12). RF84 e RF85 ficam *Em andamento* até a etapa C, que fecha a fatia.

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
| RF22 | 4 | RN14, RN16, RN65 | `leave_group`, `remove_group_member` (retirada das listas e de `game_admins`) | `/groups/:groupId`, `/groups/:groupId/members` | H01 a H03, H07, H08, H10, C16, S56, L19 | Concluído |
| RF23 | 3 | RN10 | `set_group_role` | `/groups/:groupId/members` | G19, G21, G22, S29, S31, L14 | Concluído |
| RF24 | 3 | RN13 | `set_group_role`, `leave_group`; invariante de admin da fatia 1 | `/groups/:groupId`, `/groups/:groupId/members` | G20, G24, G25, S26, S31 | Concluído |
| RF25 | 3 | — | `group_members`; leitura de `groups` pelo membro | `/groups` | K01, S18, S19 | Concluído |
| RF26 | 4 | RN06, RN15, RN20, RN21, RN23 | `games`; `create_game` | `/games/new`, `/groups/:groupId` | J01, J02, J05 a J08, S39 a S41, L15 | Concluído |
| RF27 | 4 | RN20 | `create_game` (sem rascunho) | `/games/new` | J01, J02, J05 a J08, S39 a S41, L15 | Concluído |
| RF28 | 4 | RN23 | `games.location_name`, `maps_url` | `/games/new`, `/games/:gameId` | J01, J02, J05 a J08, S39 a S41, L15 | Concluído |
| RF29 | 4 | RN05, RN24 | `games.total_cents`; estimativa no app (RN05) | `/games/new` | J07, U09, U11, S41 | Concluído |
| RF30 | 4 | RN23 | `games.starts_at`, `ends_at`, `cancellation_deadline` | `/games/new` | J01, J02, J05 a J08, S39 a S41, L15 | Concluído |
| RF31 | 4 | RN21, RN28 | `game_admins` (criador) | `/games/new` | J01, J04, S38 | Concluído |
| RF32 | 4 | RN22, RN28 | `games.receiver_id` | `/games/new` | J01, J04, S38 | Concluído |
| RF33 | 5 | RN29, RN30, RN31, RN94, RN115 | `change_receiver`; `receiver_changes` | `/games/:gameId` (Trocar recebedor) | V01 a V11, Z10 a Z15, Y04, S72, S73, L22 | Concluído |
| RF34 | 4 | RN15, RN25, RN27 | `add_game_admin`, `remove_game_admin`; `game_admins` | `/games/:gameId/admins` | J17 a J21, S54, L18 | Concluído |
| RF35 | 4 | RN16, RN25, RN26 | `remove_game_admin` (último admin) | `/games/:gameId/admins` | J17 a J21, S54, L18 | Concluído |
| RF36 | 4 | RN33, RN34, RN35 | `update_game` | `/games/:gameId/edit` | J09 a J13, S53 | Concluído |
| RF37 | 4 | RN40 | `games.slot_limit`; `game_limit_history` | `/games/new` | J03, O01, O02, O20, O21 | Concluído |
| RF38 | 4 | RN41, RN42 | `join_game` (limite) | `/games/:gameId` | J03, O01, O02, O20, O21 | Concluído |
| RF39 | 4 | RN43 | `cancel_game`; evento `game_cancelled` | `/games/:gameId` | J14 a J16, C07, S54, L15 | Concluído |
| RF40 | 5 | RN34, RN36, RN44, RN46, RN47, RN70 | `preview_complete_game`, `complete_game` | `/games/:gameId`, `/games/:gameId/complete` | T11, T12, Z01 a Z04, Z06, S62, S63, S66, L20 | Concluído |
| RF41 | 5 | RN34, RN48, RN74 | `preview_complete_game` (`owe`, valor por conta do recebedor) | `/games/:gameId/complete` | R04, R06, U13, S63 a S65, L20 | Concluído |
| RF42 | 5 | RN45, RN46, RN49 | `auto_complete_due_games` no `pg_cron`, a cada 5 min | — | T13 a T15, F03, F04, Z05, Z07, C08, M08 | Concluído |
| RF43 | 8 | RN55 | — | — | — | Pendente |
| RF44 | 4 | — | `can_view_game`; RLS de `games` | `/games`, `/games/:gameId` | W01 a W04, W13, W14, S36, S37, S50 | Concluído |
| RF45 | 4 | RN102 | `get_profile_contact` (chave Pix) | `/games/:gameId` | W08 a W11, S42, S44 | Concluído |
| RF46 | 4 | RN52, RN107 | RLS de `game_participants`, `game_waitlist`; Realtime | `/games/:gameId` | W01 a W04, W13, W14, S36, S37, S50 | Concluído |
| RF47 | 4 | RN50 | `join_game`; `game_participants` | `/games/:gameId` | O01 a O07, T03 a T05, S42 | Concluído |
| RF48 | 8 | RN50, RN107 | — | — | — | Pendente |
| RF49 | 4 | RN51, RN54 | `join_waitlist`, `leave_waitlist`; `game_waitlist` | `/games/:gameId` | O03, O04, O15, O16, T05, C03, S45, L16 | Concluído |
| RF50 | 4 | RN02, RN29, RN56, RN57 | `leave_game`; `game_participants` | `/games/:gameId` | O08 a O14, T01, T02, T06 a T10, C06, S43, S44, S47, L16, L17 | Concluído |
| RF51 | 4 | RN53 | `join_game` com trava por jogo (RN53) | `/games/:gameId` | C01, C02, C04, C05 | Concluído |
| RF52 | 4 | RN42, RN53, RN59 | `set_slot_limit` | `/games/:gameId/edit` | O20 a O23, C05, S53 | Concluído |
| RF53 | 4 | RN33, RN41, RN59 | `set_slot_limit` (redução) | `/games/:gameId/edit` | O20 a O23, C05, S53 | Concluído |
| RF54 | 4 | RN29, RN58 | `remove_participant`; `game_participants` | `/games/:gameId` | O17 a O19 | Concluído |
| RF55 | 4 | RN02, RN03, RN51 | `join_game` (prazo e início, RN03) | `/games/:gameId` | O01 a O07, T03 a T05, S42 | Concluído |
| RF56 | 5 | RN02, RN03, RN35, RN57, RN60 | `game_participants.left_at` e `late_cancellation`; `complete_game` sem valor | `/games/:gameId`, `/games/:gameId/split` | T16, S68, S71 | Concluído |
| RF57 | 5 | RN03, RN56, RN61 | `charges` (`late_cancellation_penalty`); `complete_game` | `/games/:gameId`, `/games/:gameId/split` | I01 a I12, F13, S71 | Concluído |
| RF58 | 5 | RN62 | `game_participants.late_cancellation_exempt`; `game_limit_history`; `complete_game` | `/games/:gameId/complete`, `/games/:gameId/split` | I01 a I12, Z09, S67, S68, S69 | Concluído |
| RF59 | 5 | RN58, RN65 | `removal_reason`; `complete_game` sem valor | `/games/:gameId/split` | F12, F14 | Concluído |
| RF60 | 5 | RN47, RN63 | `p_absent_user_ids`; `absence_source` | `/games/:gameId/complete` | F01, F02, F05, F08, S67, L21 | Concluído |
| RF61 | 5 | RN63 | `charges` (`absence_penalty`) | `/games/:gameId`, `/games/:gameId/split` | F01, F05, S71, L21 | Concluído |
| RF62 | 5 | RN64 | `amount_cents` = `share_cents` | `/games/:gameId/split` | F01, F05 | Concluído |
| RF63 | 5 | RN65 | `RECEIVER_CANNOT_BE_ABSENT`; `RECEIVER_LOCKED` | `/games/:gameId/complete` | F06, F07, S67 | Concluído |
| RF64 | 5 | RN36, RN66, RN93 | `waive_penalty`; `charge_events` | `/games/:gameId/split` | F09 a F11, R08, Z08, C09, S70, L21 | Concluído |
| RF65 | 5 | — | `game_participants` (as passagens de quem lê) | `/games/:gameId` (Sua participação) | S71 | Concluído |
| RF66 | 5 | RN67, RN70 | `complete_game` e `preview_complete_game` (`GAME_NOT_OPEN`) | — | Z04, V11 | Concluído |
| RF67 | 5 | RN04, RN71, RN75 | `games.share_cents`; `complete_game` | `/games/:gameId/complete`, `/games/:gameId/split` | R01 a R07, R09, R10, S63 | Concluído |
| RF68 | 5 | RN72 | `charges` (`share`) | `/games/:gameId/split` | R01 a R03, R05, R07, S68, L20 | Concluído |
| RF69 | 5 | RN72 | `charges` (`absence_penalty`, `late_cancellation_penalty`) | `/games/:gameId/split` | F01, F05, I01 a I12, S69 | Concluído |
| RF70 | 5 | RN72 | Sem valor com `late_cancellation_exempt` | `/games/:gameId/split` | I01 a I12, Z09, S68 | Concluído |
| RF71 | 5 | RN32, RN72, RN73 | `charges.receiver_id`; sem valor para o recebedor | `/games/:gameId/split` | R01, R09, S68, S69, L20 | Concluído |
| RF72 | 5 | RN73 | `charges.status`; `charge_events` | `/games/:gameId`, `/games/:gameId/split` | R10, F09, S61, S68 a S70, L21 | Concluído |
| RF73 | 5 | RN76 | RLS de `charges` (Y01 a Y03) | `/games/:gameId`, `/games/:gameId/split` | Y01 a Y03, S61, S68 | Concluído |
| RF74 | 5 | RN76 | RLS de `charges` (Y05 a Y07) | `/games/:gameId/split` | Y05 a Y07, S69, L20 | Concluído |
| RF75 | 5 | — | RLS de `charges` | `/charges` | S74 a S76, L22 | Concluído |
| RF76 | 5 | — | RLS de `charges` | `/charges` | S74 a S76, Y04 | Concluído |
| RF77 | 6 | RN102 | `charges`, `get_profile_contact` | `/charges/:chargeId` | S77, S85 | Em andamento |
| RF78 | 6 | RN86, RN87 | `process-receipt`, Storage `receipts` | — | PR04 a PR06, PR09, RS06, RS07, CP17, CP21 | Em andamento |
| RF79 | 6 | — | `process-receipt` (Claude API) | — | PR01, PR07, PR08, NM01 a NM05, CF01 a CF26 | Em andamento |
| RF80 | 6 | RN32, RN88 | `record_receipt` | — | CP01 a CP14, CP23, C12, CF01 a CF24 | Em andamento |
| RF81 | 6 | RN89 | `record_receipt`, `receipts_transaction_id_idx` | — | CP15, CP16, C10, CF22 | Em andamento |
| RF82 | 6 | RN80 | `record_receipt` | — | CP01, PR01, C11 | Em andamento |
| RF83 | 6 | RN81, RN82, RN83 | `record_receipt`, `review_receipt` | — | CP17 a CP20, RV01 a RV06, C18 | Em andamento |
| RF84 | 6 | RN84 | `mark_charge_paid` | `/games/:gameId/split` | PG01 a PG03, C09, S84, L23 | Em andamento |
| RF85 | 6 | RN85 | `revert_charge` | `/games/:gameId/split` | PG04 a PG07, S84, L23 | Em andamento |
| RF86 | 6 | RN90 | `receipts` (RLS) | — | RS01 a RS05, RS08 | Em andamento |
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
| RF101 | 4 | RN101, RN107 | `get_profile_contact` (telefone) | `/people/:userId`, `/games/:gameId/people/:userId` | W12, U12, S58, M07 | Concluído |
| RF102 | 4 | RN16 | `leave_group`, `remove_group_member` (`MEMBER_IS_RECEIVER`, `MEMBER_IS_ONLY_GAME_ADMIN`, `detail.game_ids`) | `/groups/:groupId`, `/groups/:groupId/members` | H04 a H07, H09, E16, S56, S57, L19 | Concluído |
| RF103 | 3 | RN13, RN17 | `archive_group` | `/groups/:groupId/edit` | G30 a G33, K04, S33, L13 | Concluído |
| RF104 | 7 | RN17, RN58, RN66, RN80 | — | — | — | Pendente |
| RF105 | 2 | — | `terms_acceptances`; `current_terms_versions()` | `/terms`, `/terms/:document` | P10 a P14, S09, S10, L08 | Concluído |
| RF106 | 2 | — | Auth, código no endereço novo | `/profile/email` | S11, S14, L11 | Concluído |
| RF107 | 2 | — | Auth | `/profile/password` | S11, S15 | Concluído |
| RF108 | 2 | — | Auth, vinculação de identidades | `/login`, `/profile` | U07, S11, M02 | Concluído |
