# Rastreabilidade

Liga cada requisito funcional (RF) às regras (RN), à fatia, ao banco, às telas, aos testes e ao status (`plan-docs.md`, seção 5.4). Serve para responder "o que ainda não tem teste?".

- **Fonte:** os RFs vêm de `requisitos.md`, a fatia de `plano-implementacao.md` e as RNs da última coluna de `regras-negocio.md`. Os IDs de teste são os cenários de `testes-referencia.md`.
- **Preenchimento:** banco, telas e testes entram ao fechar cada fatia. As fatias ainda não feitas têm só RN e fatia.
- **Status:** *Pendente*; *Feito no local*, com os testes automáticos verdes e o fluxo conferido no emulador; *Falta Mxx*, à espera da conferência manual; *Concluído*, depois da conferência na produção (M03 e M04, na fatia 2).
- **Critério** (`plan-docs.md`, 5.4): nenhum RF sem fatia; nenhum RF concluído sem teste.

A fatia 1 (Fundação) não tem RF: ela entrega o schema, o RLS e o CI, cobertos por `supabase/tests/database/` e pelas seções 1 a 8 de `testes-referencia.md`.

**Fatia 2, em 13/11/2026:** RFs com testes automáticos verdes e L06 a L11 nas APIs 29 e 36. M01 e M02 conferidos no celular contra o Supabase local, e M03 e M04 na produção, em 13/11/2026. Os 16 RFs da fatia estão concluídos.

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
| RF14 | 3 | RN10, RN106 | — | — | — | Pendente |
| RF15 | 3 | RN11 | — | — | — | Pendente |
| RF16 | 3 | RN12 | — | — | — | Pendente |
| RF17 | 3 | RN12 | — | — | — | Pendente |
| RF18 | 3 | RN106 | — | — | — | Pendente |
| RF19 | 3 | RN107 | — | — | — | Pendente |
| RF20 | 3 | RN14 | — | — | — | Pendente |
| RF21 | 3 | RN14 | — | — | — | Pendente |
| RF22 | 4 | RN14, RN16, RN65 | — | — | — | Pendente |
| RF23 | 3 | RN10 | — | — | — | Pendente |
| RF24 | 3 | RN13 | — | — | — | Pendente |
| RF25 | 3 | — | — | — | — | Pendente |
| RF26 | 4 | RN06, RN15, RN20, RN21, RN23 | — | — | — | Pendente |
| RF27 | 4 | RN20 | — | — | — | Pendente |
| RF28 | 4 | RN23 | — | — | — | Pendente |
| RF29 | 4 | RN05, RN24 | — | — | — | Pendente |
| RF30 | 4 | RN23 | — | — | — | Pendente |
| RF31 | 4 | RN21, RN28 | — | — | — | Pendente |
| RF32 | 4 | RN22, RN28 | — | — | — | Pendente |
| RF33 | 5 | RN29, RN30, RN31, RN94, RN115 | — | — | — | Pendente |
| RF34 | 4 | RN15, RN25, RN27 | — | — | — | Pendente |
| RF35 | 4 | RN16, RN25, RN26 | — | — | — | Pendente |
| RF36 | 4 | RN33, RN34, RN35 | — | — | — | Pendente |
| RF37 | 4 | RN40 | — | — | — | Pendente |
| RF38 | 4 | RN41, RN42 | — | — | — | Pendente |
| RF39 | 4 | RN43 | — | — | — | Pendente |
| RF40 | 5 | RN34, RN36, RN44, RN46, RN47, RN70 | — | — | — | Pendente |
| RF41 | 5 | RN34, RN48, RN74 | — | — | — | Pendente |
| RF42 | 5 | RN45, RN46, RN49 | — | — | — | Pendente |
| RF43 | 8 | RN55 | — | — | — | Pendente |
| RF44 | 4 | — | — | — | — | Pendente |
| RF45 | 4 | RN102 | — | — | — | Pendente |
| RF46 | 4 | RN107 | — | — | — | Pendente |
| RF47 | 4 | RN50 | — | — | — | Pendente |
| RF48 | 8 | RN50, RN107 | — | — | — | Pendente |
| RF49 | 4 | RN51, RN54 | — | — | — | Pendente |
| RF50 | 4 | RN02, RN29, RN56, RN57 | — | — | — | Pendente |
| RF51 | 4 | RN53 | — | — | — | Pendente |
| RF52 | 4 | RN42, RN53, RN59 | — | — | — | Pendente |
| RF53 | 4 | RN33, RN41, RN59 | — | — | — | Pendente |
| RF54 | 4 | RN29, RN58 | — | — | — | Pendente |
| RF55 | 4 | RN02, RN03, RN51 | — | — | — | Pendente |
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
| RF102 | 4 | — | — | — | — | Pendente |
| RF103 | 3 | RN13, RN17 | — | — | — | Pendente |
| RF104 | 7 | RN17, RN58, RN66, RN80 | — | — | — | Pendente |
| RF105 | 2 | — | `terms_acceptances`; `current_terms_versions()` | `/terms`, `/terms/:document` | P10 a P14, S09, S10, L08 | Concluído |
| RF106 | 2 | — | Auth, código no endereço novo | `/profile/email` | S11, S14, L11 | Concluído |
| RF107 | 2 | — | Auth | `/profile/password` | S11, S15 | Concluído |
| RF108 | 2 | — | Auth, vinculação de identidades | `/login`, `/profile` | U07, S11, M02 | Concluído |
