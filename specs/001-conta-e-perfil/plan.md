# Implementation Plan: Conta e perfil (fatia 2)

**Branch**: `fatia-2/conta-e-perfil` | **Date**: 2026-11-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-conta-e-perfil/spec.md`

## Summary

A fatia 2 completa o acesso (cadastro com código por e-mail, Google, recuperação de senha, aceite dos termos) e troca a aba Perfil provisória pela tela real, com as edições de perfil, chave Pix, e-mail e senha (`docs/plano-implementacao.md`, fatia 2).

No servidor, não há tabela nova: a fatia concede o acesso da própria linha em `profiles`, `profile_private` e `terms_acceptances`, cria `current_terms_versions()`, a *trigger* da RN105, a conferência dos dígitos de CPF e CNPJ e as três políticas do bucket `avatars` (`docs/rls-matriz.md`, fatia 2). O Supabase Auth passa a confirmar por código (ADR 0017), com os três modelos de e-mail.

No app, a feature `auth` ganha as camadas `domain` e `data` completas e as telas da seção 5 do `docs/ui/telas.md`, seguindo os PNGs de `docs/ui/referencias/fatia-2/`.

## Technical Context

**Language/Version**: Dart 3.13 (Flutter 3.47, estável); SQL (Postgres 17 do Supabase local); TypeScript no Deno 2.x, só para o teste do Storage.

**Primary Dependencies**: as de `docs/arquitetura-app.md`, seção 3. Entram nesta fatia `google_sign_in` 7.2 e `image_picker` 1.2, ambos já previstos na tabela.

**Storage**: Postgres do Supabase (tabelas da seção 4.1 do `docs/modelo-dados.md`) e o bucket privado `avatars`.

**Testing**: pgTAP (`supabase test db`), Deno test (Storage), `flutter_test` com `mocktail` (unitário e widget) e `integration_test` no emulador (`docs/testes-referencia.md`, seção 10).

**Target Platform**: Android, API 29 a 36 (RNF01, RNF02).

**Project Type**: app móvel com backend gerenciado (`app/` e `supabase/`).

**Performance Goals**: os da RNF04. Nenhuma meta nova nesta fatia.

**Constraints**: só modo escuro; fonte do sistema em 150% (RNF05); nada guardado no aparelho além da sessão (RNF07); o servidor decide e o app exibe.

**Scale/Scope**: 10 rotas novas ou completadas, 5 migrações, 3 modelos de e-mail e os cenários P, X, N, A, U, E, S e L da seção 10 do `docs/testes-referencia.md`.

## Constitution Check

*GATE: conferido antes da pesquisa e de novo depois do desenho.*

| Princípio | Situação |
|-----------|----------|
| I. Os documentos são a fonte da verdade | Passa. O spec e este plano citam `docs/`. As duas divergências achadas na pesquisa (R5 e R9 do `research.md`) viram correção de documento no mesmo PR, sinalizada ao responsável |
| II. Uma fatia por vez | Passa. Ficam de fora RF13, RF101, o token de push e a leitura por contexto |
| III. Testes antes do código | Passa. A fase 2 do `tasks.md` é só de testes, com *commit* próprio e a saída da falha |
| IV. O servidor decide | Passa. Formato da chave Pix, RN105, versão dos termos e limites da foto são do banco e do Storage. O app repete as conferências só para o aviso no campo |
| V. Produção é do responsável | Passa. O plano entrega os comandos e a lista do painel no `quickstart.md`. M01 a M04 são do responsável |

Nenhuma violação a justificar.

## Project Structure

### Documentation (this feature)

```text
specs/001-conta-e-perfil/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── repositories.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
supabase/
├── config.toml                      # código por e-mail, senha de 8, Google, modelos, limite de envio
├── templates/                       # confirmation.html, recovery.html, email_change.html
├── migrations/                      # 5 migrações novas (data-model.md)
├── seed.sql                         # perfis completos (setup.md, seção 8)
├── tests/database/
│   ├── base_security.test.sql       # listas esperadas da fatia 2 (B03, B04, B06, B08, B10)
│   ├── account_security.test.sql    # P01 a P16
│   └── account_pix.test.sql         # X01 a X10, N01 a N09
└── functions/_tests/avatars_test.ts # A01 a A06

app/lib/
├── core/
│   ├── errors/                      # códigos e textos novos; Storage e Auth sem rede
│   ├── format/                      # phone.dart, pix_key.dart, input_masks.dart
│   └── router/                      # rotas e redirecionamentos da fatia 2
├── features/auth/
│   ├── domain/                      # profile, profile_private, pix_key_type, legal_document, terms, auth_access
│   ├── data/                        # auth_repository, google_id_token_source, profile_repository, terms_repository
│   └── presentation/                # providers, controllers, telas e widgets da feature
└── shared/widgets/                  # componentes do design system usados por mais de uma tela

app/test/                            # espelha lib/ (U, E, S)
app/integration_test/                # account_flow_test.dart (L08 a L11)
.github/workflows/ci.yml             # o teste do Storage roda no job que sobe o Supabase
```

**Structure Decision**: a estrutura é a de `docs/arquitetura-app.md`, seção 2, e de `docs/setup.md`, seção 2. Tudo da fatia fica na feature `auth`, que já cobre RF01 a RF13 e RF105 a RF108. Os contratos internos do app (o que cada repositório expõe às telas e aos dublês dos testes) estão em `contracts/repositories.md`.

## Complexity Tracking

Sem violações.
