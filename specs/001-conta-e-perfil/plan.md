# Plano de implementação: Fatia 2 — Conta e perfil

**Branch**: `fatia-2/conta-e-perfil` | **Data**: 2026-11-12 | **Especificação**: [spec.md](spec.md)

**Entrada**: `specs/001-conta-e-perfil/spec.md`

## Resumo

Completar o acesso (cadastro por e-mail com código, Google, recuperação de senha, aceite dos termos) e trocar a aba Perfil vazia pelo perfil real (edição, foto, telefone, chave Pix, troca de e-mail e de senha). No servidor: privilégios e políticas da fatia 2 (`rls-matriz.md`), `current_terms_versions()`, dígitos verificadores de CPF e CNPJ na constraint da chave Pix, *trigger* da RN105, políticas do bucket `avatars` e configuração do Supabase Auth com os modelos de e-mail. No app: oito telas novas, a `/login` completada, a conferência dos termos no roteador e a conversão dos novos erros. Decisões técnicas em [research.md](research.md).

## Contexto técnico

**Linguagem/versão**: Dart 3.13 com Flutter estável 3.47 ou superior (app); SQL do Postgres 17 (Supabase); TypeScript no Deno 2.x (teste das fotos).

**Dependências principais**: as do `app/pubspec.yaml` mais `google_sign_in` e `image_picker`, ambos na tabela da seção 3 do `arquitetura-app.md` e no `stacks.md` (3.1). Nenhum pacote fora das listas.

**Armazenamento**: Postgres (`profiles`, `profile_private`, `terms_acceptances`, já criadas na fatia 1) e Storage (bucket `avatars`, já criado).

**Testes**: pgTAP (`supabase test db`), Deno test contra o Storage local, `flutter_test` (unitário e widget) e `integration_test` no emulador (`arquitetura-app.md`, seção 11 e 14.4).

**Plataforma alvo**: Android, API 29 a 36 (`requisitos-nao-funcionais.md`).

**Tipo de projeto**: app móvel com backend Supabase.

**Metas de desempenho**: abertura em até 3 s e telas comuns em até 2 s (RNF04).

**Restrições**: nada guardado no aparelho além da sessão do Supabase (RNF07); textos só do ARB; cores só do tema; fonte em 150% sem *overflow* (RNF05); sem segredo no app.

**Escala/escopo**: 9 rotas novas ou completadas, 5 migrações novas, 3 arquivos de teste no servidor e ~20 no app.

## Verificação da constituição

*Portão: antes da fase 0 e de novo depois da fase 1.*

| Princípio | Como o plano cumpre | Situação |
|-----------|--------------------|----------|
| I. Documentos são a fonte da verdade | `spec.md` só cita; valores, textos e políticas vêm de `rls-matriz.md`, `copy.md`, `telas.md` e `testes-referencia.md` | Passa |
| II. Uma fatia por vez | Fora de escopo da fatia respeitado: sem RF13, RF101, RN107 e token de push | Passa |
| III. Testes antes do código | Ordem de tarefas: testes pgTAP, Deno e Flutter num *commit* antes de cada implementação, com a falha registrada | Passa |
| IV. O servidor decide | RN105 e formato da chave no banco (*trigger* e constraint); tipo e tamanho da foto no bucket; instante do aceite pelo `now()`; o app só repete as validações para avisar no campo | Passa |
| V. Produção é do responsável | O plano entrega os comandos da produção (migrações, painel do Auth, SMTP do Resend) para o responsável executar | Passa |

**Depois da fase 1**: sem violação. Nenhuma tabela, coluna, enum ou função nova além das previstas nos documentos. `private.is_valid_cpf` e `private.is_valid_cnpj` estão no `modelo-dados.md` (4.1); `current_terms_versions()` no `contratos-api.md` (9).

## Estrutura do projeto

### Documentação (esta fatia)

```text
specs/001-conta-e-perfil/
├── spec.md
├── plan.md              # este arquivo
├── research.md          # fase 0
├── data-model.md        # fase 1
├── quickstart.md        # fase 1
├── contracts/
│   └── app-servidor.md  # fase 1: o que o app chama no Auth, no banco e no Storage
└── tasks.md             # /speckit-tasks
```

### Código

```text
supabase/
├── config.toml                                   # Auth: confirmação, OTP, senha 8, Google, modelos, limite de e-mail
├── templates/
│   ├── confirmation.html
│   ├── recovery.html
│   └── email_change.html
├── migrations/
│   ├── <ts>_create_current_terms_versions.sql
│   ├── <ts>_account_rls.sql                      # grants e políticas das três tabelas
│   ├── <ts>_avatars_profile_policies.sql         # storage.objects, pasta profiles/{uid}
│   ├── <ts>_pix_key_check_digits.sql             # private.is_valid_cpf/cnpj e constraint nova
│   └── <ts>_pix_key_removal_trigger.sql          # RN105
├── seed.sql                                      # perfis completos da fatia 2
├── tests/database/
│   ├── base_security.test.sql                    # B03, B04, B06, B10 com as listas da fatia 2
│   ├── account_security.test.sql                 # P01 a P16
│   └── account_pix.test.sql                      # X01 a X10, N01 a N09
└── functions/_tests/avatars_test.ts              # A01 a A06

app/lib/
├── core/
│   ├── errors/        # ErrorCode, mapper e textos novos (E09 a E12)
│   ├── format/        # phone.dart, br_documents.dart, pix_key.dart (U01 a U06)
│   └── router/        # rotas novas, redirect dos termos e das rotas de e-mail e senha
├── shared/widgets/    # AppAvatar, CodeField, ResendCodeButton, PasswordField, FieldLabel, NavRow, ConfirmDialog
└── features/auth/
    ├── data/          # auth_repository.dart (Auth e Google), profile_repository.dart, terms_repository.dart
    ├── domain/        # Profile, ProfilePrivate, PixKeyType, LegalDocument, TermsStatus
    └── presentation/  # telas e controllers da seção 5 do telas.md

app/test/            # espelha lib/ (U, E, S)
app/integration_test/ # L08 a L11
.github/workflows/ci.yml  # Deno do avatars_test no job do banco
```

**Decisão de estrutura**: a do `arquitetura-app.md` (seção 2). Tudo da conta fica em `features/auth`, como o próprio guia define (RF01 a RF13, RF105 a RF108). Componentes usados por mais de uma tela sobem para `shared/widgets/`.

## Ordem de execução

1. Servidor: testes pgTAP (falham) → migrações → testes verdes. Depois o teste Deno das fotos.
2. Auth local: `config.toml` e modelos de e-mail.
3. App, base: erros, formatação e validação (testes unitários primeiro), modelos, repositórios.
4. App, telas: por história, na ordem de prioridade da especificação, cada uma com o teste de widget antes.
5. Fluxos de integração (L08 a L11), seed, CI e documentos.

## Acompanhamento de complexidade

Sem violação a justificar.
